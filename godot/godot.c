// Godot
// =====

// The host side of Godot.bend. Bend pastes this file into the one C file
// it emits, so everything below sees the runtime's internals (io_step,
// io_runs, corpus_setup) and needs no patch to the compiler.
//
// A Bend binary owns its process: main() builds the IO action and io_loop
// runs it until the program ends. A GDExtension is the opposite, Godot owns
// the loop and calls in. The bridge is one effect, gd.frame, which parks
// its activation (IO_PARK) instead of answering. BendRuntime._process then
// answers it with the frame's delta and pumps the run queue until it is
// empty again, that is, until the program asks for the next frame. Every
// other effect runs inside that pump, on Godot's main thread, so it may
// call any Godot API directly.

#include "gdextension_interface.h"

// Interface
// ---------

static GDExtensionClassLibraryPtr                       gd_lib;
static GDExtensionInterfaceStringNameNewWithLatin1Chars gd_sn_new;
static GDExtensionInterfaceStringNewWithUtf8CharsAndLen gd_str_new;
static GDExtensionInterfaceVariantDestroy               gd_var_free;
static GDExtensionInterfaceClassdbConstructObject2      gd_construct;
static GDExtensionInterfaceObjectSetInstance            gd_set_instance;
static GDExtensionVariantFromTypeConstructorFunc        gd_var_from_str;
static GDExtensionPtrDestructor                         gd_str_free;
static GDExtensionPtrUtilityFunction                    gd_util_print;

// A StringName, a String and a Variant, as opaque storage of their size.
typedef struct { void* p; }     GdName;
typedef struct { void* p; }     GdStr;
typedef struct { u64 w[3]; }    GdVar;

static GdName gd_n_node;
static GdName gd_n_runtime;
static GdName gd_n_ready;
static GdName gd_n_process;

static GdName gd_name(const char* s) {
  GdName n;
  gd_sn_new(&n, s, 1);
  return n;
}

// Pump
// ----

static bool   gd_up;        // the corpus is set and main is spawned
static int    gd_code = -1; // main's exit code, once it halts
static IoAct* gd_waiter;    // the activation parked on gd.frame

// Runs every ready computation up to its next parked effect. The native
// io_loop blocks in io_wait when the queue is empty; here an empty queue
// hands the thread back to Godot.
static void gd_pump(void) {
  Env e = { CORPUS, ALC[0] };
  while (gd_code < 0 && io_runs.head != NULL) {
    gd_code = io_step(e, io_pop(&io_runs));
  }
}

static void gd_boot(void) {
  Corpus H = corpus_setup(false, cpu_count(), 0);
  Env    e = { H, ALC[0] };
  io_stk = pool_stack();
  signal(SIGPIPE, SIG_IGN);
  if (pipe(io_wake_fd) | fcntl(io_wake_fd[0], F_SETFL, O_NONBLOCK)) {
    err_fail("the event loop failed to open");
  }
  io_spawn(corpus_eval(H, term_tsk(MAIN_FID, task_node(e, MAIN_FID,
    TERM_HOLE, 0, 0))));
  gd_up = true;
  gd_pump();
}

// Effects
// -------

// gd.print : String -> IO(Unit), through Godot's own print, so the text
// lands in the editor's Output panel too.
Term gd_print_run(Env e, Term* f, IoWork* w) {
  uint64_t n = 0;
  char* text = io_cstr(e, f[0], &n);
  GdStr s;
  GdVar v;
  gd_str_new(&s, text, (GDExtensionInt)n);
  gd_var_from_str(&v, &s);
  GDExtensionConstTypePtr args[1] = { &v };
  gd_util_print(NULL, args, 1);
  gd_var_free(&v);
  gd_str_free(&s);
  free(text);
  return term_pak(CID_UNIT, 0);
}

// gd.frame : IO(U32), the microseconds since the last frame. Parks until
// BendRuntime._process answers it.
Term gd_frame_run(Env e, Term* f, IoWork* w) {
  gd_waiter = (IoAct*)w;
  return IO_PARK;
}

static void __attribute__((constructor)) gd_use(void) {
  io_eff(CID_GD_PRINT, gd_print_run, 0);
  io_eff(CID_GD_FRAME, gd_frame_run, 0);
}

// BendRuntime
// -----------

// The node that hosts the program: _ready boots Bend and runs main up to
// its first gd.frame, _process resumes it once per frame.
static GDExtensionObjectPtr gd_rt_create(void* data, GDExtensionBool notify) {
  GDExtensionObjectPtr o = gd_construct(&gd_n_node);
  gd_set_instance(o, &gd_n_runtime, o);
  return o;
}

static void gd_rt_free(void* data, GDExtensionClassInstancePtr self) {
}

static void* gd_rt_virtual(void* data, GDExtensionConstStringNamePtr name,
  uint32_t hash) {
  void* p = ((const GdName*)name)->p;
  return p == gd_n_ready.p ? &gd_n_ready : p == gd_n_process.p
    ? &gd_n_process : NULL;
}

static void gd_rt_call(GDExtensionClassInstancePtr self,
  GDExtensionConstStringNamePtr name, void* which,
  const GDExtensionConstTypePtr* args, GDExtensionTypePtr ret) {
  if (which == &gd_n_ready) {
    if (!gd_up) {
      gd_boot();
    }
    return;
  }
  if (gd_waiter == NULL || gd_code >= 0) {
    return;
  }
  IoAct* a  = gd_waiter;
  gd_waiter = NULL;
  a->item   = (Term)(u32)(*(const double*)args[0] * 1e6);
  io_push(&io_runs, a);
  gd_pump();
}

// Entry
// -----

static void gd_level_init(void* data, GDExtensionInitializationLevel level) {
  if (level != GDEXTENSION_INITIALIZATION_SCENE) {
    return;
  }
  GDExtensionClassCreationInfo4 info = {
    .is_exposed                  = 1,
    .is_runtime                  = 1,
    .create_instance_func        = gd_rt_create,
    .free_instance_func          = gd_rt_free,
    .get_virtual_call_data_func  = gd_rt_virtual,
    .call_virtual_with_data_func = gd_rt_call,
  };
  GDExtensionInterfaceClassdbRegisterExtensionClass4 reg =
    (GDExtensionInterfaceClassdbRegisterExtensionClass4)
    ((GDExtensionInterfaceGetProcAddress)data)(
    "classdb_register_extension_class4");
  reg(gd_lib, &gd_n_runtime, &gd_n_node, &info);
}

static void gd_level_exit(void* data, GDExtensionInitializationLevel level) {
}

__attribute__((visibility("default")))
GDExtensionBool godot_bend_init(GDExtensionInterfaceGetProcAddress get,
  GDExtensionClassLibraryPtr lib, GDExtensionInitialization* init) {
  gd_lib          = lib;
  gd_sn_new       = (GDExtensionInterfaceStringNameNewWithLatin1Chars)
    get("string_name_new_with_latin1_chars");
  gd_str_new      = (GDExtensionInterfaceStringNewWithUtf8CharsAndLen)
    get("string_new_with_utf8_chars_and_len");
  gd_var_free     = (GDExtensionInterfaceVariantDestroy)
    get("variant_destroy");
  gd_construct    = (GDExtensionInterfaceClassdbConstructObject2)
    get("classdb_construct_object2");
  gd_set_instance = (GDExtensionInterfaceObjectSetInstance)
    get("object_set_instance");
  gd_var_from_str = ((GDExtensionInterfaceGetVariantFromTypeConstructor)
    get("get_variant_from_type_constructor"))(GDEXTENSION_VARIANT_TYPE_STRING);
  gd_str_free     = ((GDExtensionInterfaceVariantGetPtrDestructor)
    get("variant_get_ptr_destructor"))(GDEXTENSION_VARIANT_TYPE_STRING);
  gd_n_node    = gd_name("Node");
  gd_n_runtime = gd_name("BendRuntime");
  gd_n_ready   = gd_name("_ready");
  gd_n_process = gd_name("_process");
  GdName print = gd_name("print");
  gd_util_print = ((GDExtensionInterfaceVariantGetPtrUtilityFunction)
    get("variant_get_ptr_utility_function"))(&print, 2648703342);
  init->minimum_initialization_level = GDEXTENSION_INITIALIZATION_SCENE;
  init->userdata     = (void*)get;
  init->initialize   = gd_level_init;
  init->deinitialize = gd_level_exit;
  return 1;
}
