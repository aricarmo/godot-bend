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
static GDExtensionInterfaceStringNameNewWithUtf8CharsAndLen gd_sn_utf8;
static GDExtensionInterfaceStringNewWithUtf8CharsAndLen gd_str_new;
static GDExtensionInterfaceStringToUtf8Chars            gd_str_utf8;
static GDExtensionInterfaceVariantNewNil                gd_var_nil;
static GDExtensionInterfaceVariantNewCopy               gd_var_copy;
static GDExtensionInterfaceVariantDestroy               gd_var_free;
static GDExtensionInterfaceVariantCall                  gd_var_call;
static GDExtensionInterfaceVariantGetType               gd_var_type;
static GDExtensionInterfaceVariantStringify             gd_var_text;
static GDExtensionInterfaceClassdbConstructObject2      gd_construct;
static GDExtensionInterfaceObjectSetInstance            gd_set_instance;
static GDExtensionInterfaceObjectGetInstanceId          gd_obj_id;
static GDExtensionInterfaceObjectGetInstanceFromId      gd_obj_at;
static GDExtensionInterfaceGlobalGetSingleton           gd_global;
static GDExtensionPtrDestructor                         gd_str_free;
static GDExtensionPtrDestructor                         gd_sn_free;
static GDExtensionPtrUtilityFunction                    gd_util_print;
static GDExtensionPtrUtilityFunction                    gd_util_error;

// A StringName, a String and a Variant, as opaque storage of their size
// (a Variant is 24 bytes in a single-precision build, the official one).
typedef struct { void* p; }  GdName;
typedef struct { void* p; }  GdStr;
typedef struct { u64 w[3]; } GdVar;
typedef struct { f32 x, y; } GdVec2;

// The kinds this binding carries, and Godot's constructors between each
// and a Variant.
enum { GD_BOOL, GD_INT, GD_FLOAT, GD_STR, GD_VEC2, GD_OBJ, GD_KINDS };

static const GDExtensionVariantType gd_types[GD_KINDS] = {
  GDEXTENSION_VARIANT_TYPE_BOOL,    GDEXTENSION_VARIANT_TYPE_INT,
  GDEXTENSION_VARIANT_TYPE_FLOAT,   GDEXTENSION_VARIANT_TYPE_STRING,
  GDEXTENSION_VARIANT_TYPE_VECTOR2, GDEXTENSION_VARIANT_TYPE_OBJECT,
};

static GDExtensionVariantFromTypeConstructorFunc gd_from[GD_KINDS];
static GDExtensionTypeFromVariantConstructorFunc gd_into[GD_KINDS];

static GdName gd_n_node;
static GdName gd_n_runtime;
static GdName gd_n_ready;
static GdName gd_n_process;

// Never a static StringName: that one keeps a pointer to s, a literal of
// this library, which Godot may unload before the name's last reader.
static GdName gd_name(const char* s) {
  GdName n;
  gd_sn_new(&n, s, 0);
  return n;
}

// Reports through Godot's push_error, so a mistake shows in the debugger.
static void gd_error(const char* what, const char* name) {
  char  text[256];
  int   n = snprintf(text, sizeof text, "bend: %s%s", what, name);
  GdStr s;
  GdVar v;
  gd_str_new(&s, text, n < (int)sizeof text ? n : (int)sizeof text - 1);
  gd_from[GD_STR](&v, &s);
  GDExtensionConstTypePtr args[1] = { &v };
  gd_util_error(NULL, args, 1);
  gd_var_free(&v);
  gd_str_free(&s);
}

// Objects
// -------

// A Bend Object is a slot of this table. A row keeps the instance id, the
// test that the object still lives, and a Variant of it, which holds a
// RefCounted (a texture, any Resource) alive while the program may name
// it. Rows are found again by id, so an object met every frame keeps one
// slot; none is freed yet. Slot 0 is null.
typedef struct {
  u64   id;
  GdVar var;
} GdRow;

static GdRow* gd_rows;
static u32    gd_rows_len = 1;
static u32    gd_rows_cap;
static u32*   gd_index;     // open addressing, id -> slot, 0 is empty
static u32    gd_index_cap;

static void gd_index_put(u64 id, u32 slot) {
  u32 i = (u32)(id * 0x9E3779B97F4A7C15ull >> 32) & (gd_index_cap - 1);
  while (gd_index[i] != 0) {
    i = (i + 1) & (gd_index_cap - 1);
  }
  gd_index[i] = slot;
}

static u32 gd_slot_of(const GdVar* v) {
  GDExtensionObjectPtr o = NULL;
  gd_into[GD_OBJ](&o, (GDExtensionVariantPtr)v);
  if (o == NULL) {
    return 0;
  }
  u64 id = gd_obj_id(o);
  if (gd_index_cap != 0) {
    u32 i = (u32)(id * 0x9E3779B97F4A7C15ull >> 32) & (gd_index_cap - 1);
    for (; gd_index[i] != 0; i = (i + 1) & (gd_index_cap - 1)) {
      if (gd_rows[gd_index[i]].id == id) {
        return gd_index[i];
      }
    }
  }
  if (gd_rows_len >= gd_rows_cap) {
    gd_rows_cap = gd_rows_cap == 0 ? 64 : 2 * gd_rows_cap;
    gd_rows     = io_mem(realloc(gd_rows, gd_rows_cap * sizeof(GdRow)));
  }
  if (2 * gd_rows_len >= gd_index_cap) {
    gd_index_cap = gd_index_cap == 0 ? 256 : 2 * gd_index_cap;
    free(gd_index);
    gd_index = io_mem(calloc(gd_index_cap, sizeof(u32)));
    for (u32 s = 1; s < gd_rows_len; s += 1) {
      gd_index_put(gd_rows[s].id, s);
    }
  }
  u32 slot = gd_rows_len;
  gd_rows_len += 1;
  gd_rows[slot].id = id;
  gd_var_copy(&gd_rows[slot].var, (GDExtensionConstVariantPtr)v);
  gd_index_put(id, slot);
  return slot;
}

static u32 gd_slot_new(GDExtensionObjectPtr o) {
  GdVar v;
  gd_from[GD_OBJ](&v, &o);
  u32 slot = gd_slot_of(&v);
  gd_var_free(&v);
  return slot;
}

// The row's Variant, or NULL for null, a bad slot, or a freed object.
static GdVar* gd_slot_var(u32 slot) {
  if (slot == 0 || slot >= gd_rows_len
    || gd_obj_at(gd_rows[slot].id) == NULL) {
    return NULL;
  }
  return &gd_rows[slot].var;
}

// Stack
// -----

static GdVar* gd_stack;
static u32    gd_sp;
static u32    gd_stack_cap;

static GdVar* gd_push(void) {
  if (gd_sp == gd_stack_cap) {
    gd_stack_cap = gd_stack_cap == 0 ? 32 : 2 * gd_stack_cap;
    gd_stack     = io_mem(realloc(gd_stack, gd_stack_cap * sizeof(GdVar)));
  }
  gd_sp += 1;
  return &gd_stack[gd_sp - 1];
}

// The top, popped: the caller reads it, then frees it. An empty stack is
// a bug in Godot.bend, never in a program.
static GdVar* gd_top(void) {
  if (gd_sp == 0) {
    err_fail("godot: a pop on an empty stack");
  }
  gd_sp -= 1;
  return &gd_stack[gd_sp];
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

#define GD_UNIT term_pak(CID_UNIT, 0)

static GDExtensionObjectPtr gd_self;

// gd.print, through Godot's own print, so the text lands in the editor's
// Output panel too.
Term gd_print_run(Env e, Term* f, IoWork* w) {
  uint64_t n = 0;
  char* text = io_cstr(e, f[0], &n);
  GdStr s;
  GdVar v;
  gd_str_new(&s, text, (GDExtensionInt)n);
  gd_from[GD_STR](&v, &s);
  GDExtensionConstTypePtr args[1] = { &v };
  gd_util_print(NULL, args, 1);
  gd_var_free(&v);
  gd_str_free(&s);
  free(text);
  return GD_UNIT;
}

// gd.frame parks until BendRuntime._process answers it.
Term gd_frame_run(Env e, Term* f, IoWork* w) {
  gd_waiter = (IoAct*)w;
  return IO_PARK;
}

Term gd_self_run(Env e, Term* f, IoWork* w) {
  return (Term)gd_slot_new(gd_self);
}

Term gd_singleton_run(Env e, Term* f, IoWork* w) {
  uint64_t n = 0;
  char*  text = io_cstr(e, f[0], &n);
  GdName name;
  gd_sn_utf8(&name, text, (GDExtensionInt)n);
  GDExtensionObjectPtr o = gd_global(&name);
  if (o == NULL) {
    gd_error("no singleton named ", text);
  }
  gd_sn_free(&name);
  free(text);
  return (Term)(o == NULL ? 0 : gd_slot_new(o));
}

Term gd_new_run(Env e, Term* f, IoWork* w) {
  uint64_t n = 0;
  char*  text = io_cstr(e, f[0], &n);
  GdName name;
  gd_sn_utf8(&name, text, (GDExtensionInt)n);
  GDExtensionObjectPtr o = gd_construct(&name);
  if (o == NULL) {
    gd_error("no class to instantiate named ", text);
  }
  gd_sn_free(&name);
  free(text);
  return (Term)(o == NULL ? 0 : gd_slot_new(o));
}

Term gd_push_nil_run(Env e, Term* f, IoWork* w) {
  gd_var_nil(gd_push());
  return GD_UNIT;
}

Term gd_push_bool_run(Env e, Term* f, IoWork* w) {
  GDExtensionBool v = (u32)f[0] != 0;
  gd_from[GD_BOOL](gd_push(), &v);
  return GD_UNIT;
}

Term gd_push_int_run(Env e, Term* f, IoWork* w) {
  int64_t v = (u32)f[0];
  gd_from[GD_INT](gd_push(), &v);
  return GD_UNIT;
}

Term gd_push_float_run(Env e, Term* f, IoWork* w) {
  double v = f32_unbox(f[0]);
  gd_from[GD_FLOAT](gd_push(), &v);
  return GD_UNIT;
}

Term gd_push_str_run(Env e, Term* f, IoWork* w) {
  uint64_t n = 0;
  char* text = io_cstr(e, f[0], &n);
  GdStr s;
  gd_str_new(&s, text, (GDExtensionInt)n);
  gd_from[GD_STR](gd_push(), &s);
  gd_str_free(&s);
  free(text);
  return GD_UNIT;
}

Term gd_push_vec2_run(Env e, Term* f, IoWork* w) {
  GdVec2 v = { f32_unbox(f[0]), f32_unbox(f[1]) };
  gd_from[GD_VEC2](gd_push(), &v);
  return GD_UNIT;
}

Term gd_push_obj_run(Env e, Term* f, IoWork* w) {
  GdVar* v = gd_slot_var((u32)f[0]);
  if (v == NULL) {
    gd_var_nil(gd_push());
  } else {
    gd_var_copy(gd_push(), v);
  }
  return GD_UNIT;
}

// gd.call pops argc arguments and pushes the result. A failed call (a
// freed object, no such method, a bad argument) reports and pushes Nil.
Term gd_call_run(Env e, Term* f, IoWork* w) {
  uint64_t n = 0;
  GdVar* self = gd_slot_var((u32)f[0]);
  char*  text = io_cstr(e, f[1], &n);
  u32    argc = (u32)f[2];
  if (argc > gd_sp) {
    err_fail("godot: a call with more arguments than the stack holds");
  }
  GdVar* args = gd_stack + (gd_sp - argc);
  GdVar  ret;
  if (self == NULL) {
    gd_error("a call on null or on a freed object: ", text);
    gd_var_nil(&ret);
  } else {
    GDExtensionConstVariantPtr ptrs[argc + 1];
    for (u32 i = 0; i < argc; i += 1) {
      ptrs[i] = &args[i];
    }
    GdName name;
    GDExtensionCallError err = { 0 };
    gd_sn_utf8(&name, text, (GDExtensionInt)n);
    gd_var_call(self, &name, ptrs, argc, &ret, &err);
    gd_sn_free(&name);
    if (err.error != GDEXTENSION_CALL_OK) {
      gd_error(err.error == GDEXTENSION_CALL_ERROR_INVALID_METHOD
        ? "no such method: " : "a call with bad arguments: ", text);
    }
  }
  for (u32 i = 0; i < argc; i += 1) {
    gd_var_free(&args[i]);
  }
  gd_sp -= argc;
  *gd_push() = ret;
  free(text);
  return GD_UNIT;
}

// gd.kind, by Godot.bend's numbering; a null object counts as Nil, and a
// StringName or a NodePath as the String it pops as.
Term gd_kind_run(Env e, Term* f, IoWork* w) {
  if (gd_sp == 0) {
    err_fail("godot: a kind on an empty stack");
  }
  GdVar* v = &gd_stack[gd_sp - 1];
  switch (gd_var_type(v)) {
    case GDEXTENSION_VARIANT_TYPE_NIL:         return 0;
    case GDEXTENSION_VARIANT_TYPE_BOOL:        return 1;
    case GDEXTENSION_VARIANT_TYPE_INT:         return 2;
    case GDEXTENSION_VARIANT_TYPE_FLOAT:       return 3;
    case GDEXTENSION_VARIANT_TYPE_STRING:
    case GDEXTENSION_VARIANT_TYPE_STRING_NAME:
    case GDEXTENSION_VARIANT_TYPE_NODE_PATH:   return 4;
    case GDEXTENSION_VARIANT_TYPE_VECTOR2:     return 5;
    case GDEXTENSION_VARIANT_TYPE_OBJECT:      return gd_slot_of(v) ? 6 : 0;
    default:                                   return 7;
  }
}

Term gd_pop_run(Env e, Term* f, IoWork* w) {
  gd_var_free(gd_top());
  return GD_UNIT;
}

Term gd_pop_bool_run(Env e, Term* f, IoWork* w) {
  GdVar* v = gd_top();
  GDExtensionBool b = 0;
  gd_into[GD_BOOL](&b, v);
  gd_var_free(v);
  return term_pak(b ? CID_TRUE : CID_FALSE, 0);
}

Term gd_pop_int_run(Env e, Term* f, IoWork* w) {
  GdVar*  v = gd_top();
  int64_t n = 0;
  gd_into[GD_INT](&n, v);
  gd_var_free(v);
  return (Term)(u32)n;
}

Term gd_pop_float_run(Env e, Term* f, IoWork* w) {
  GdVar* v = gd_top();
  double n = 0;
  gd_into[GD_FLOAT](&n, v);
  gd_var_free(v);
  return f32_rewrap((f32)n);
}

Term gd_pop_str_run(Env e, Term* f, IoWork* w) {
  GdVar* v = gd_top();
  GdStr  s;
  gd_var_text(v, &s);
  GDExtensionInt n = gd_str_utf8(&s, NULL, 0);
  char* text = io_mem(malloc((size_t)n + 1));
  gd_str_utf8(&s, text, n);
  Term t = io_str(e, text, (u64)n);
  free(text);
  gd_str_free(&s);
  gd_var_free(v);
  return t;
}

Term gd_pop_vec2_run(Env e, Term* f, IoWork* w) {
  GdVar* v = gd_top();
  GdVec2 p = { 0, 0 };
  gd_into[GD_VEC2](&p, v);
  gd_var_free(v);
  return io_tup(e, f32_rewrap(p.x), f32_rewrap(p.y));
}

Term gd_pop_obj_run(Env e, Term* f, IoWork* w) {
  GdVar* v = gd_top();
  u32 slot = gd_slot_of(v);
  gd_var_free(v);
  return (Term)slot;
}

// Bend drops a def no program reaches, and its CID_ macro with it, so
// each effect registers only when the program can ask for it.
static void __attribute__((constructor)) gd_use(void) {
#ifdef CID_GD_PRINT
  io_eff(CID_GD_PRINT, gd_print_run, 0);
#endif
#ifdef CID_GD_FRAME
  io_eff(CID_GD_FRAME, gd_frame_run, 0);
#endif
#ifdef CID_GD_SELF
  io_eff(CID_GD_SELF, gd_self_run, 0);
#endif
#ifdef CID_GD_SINGLETON
  io_eff(CID_GD_SINGLETON, gd_singleton_run, 0);
#endif
#ifdef CID_GD_NEW
  io_eff(CID_GD_NEW, gd_new_run, 0);
#endif
#ifdef CID_GD_PUSH_NIL
  io_eff(CID_GD_PUSH_NIL, gd_push_nil_run, 0);
#endif
#ifdef CID_GD_PUSH_BOOL
  io_eff(CID_GD_PUSH_BOOL, gd_push_bool_run, 0);
#endif
#ifdef CID_GD_PUSH_INT
  io_eff(CID_GD_PUSH_INT, gd_push_int_run, 0);
#endif
#ifdef CID_GD_PUSH_FLOAT
  io_eff(CID_GD_PUSH_FLOAT, gd_push_float_run, 0);
#endif
#ifdef CID_GD_PUSH_STR
  io_eff(CID_GD_PUSH_STR, gd_push_str_run, 0);
#endif
#ifdef CID_GD_PUSH_VEC2
  io_eff(CID_GD_PUSH_VEC2, gd_push_vec2_run, 0);
#endif
#ifdef CID_GD_PUSH_OBJ
  io_eff(CID_GD_PUSH_OBJ, gd_push_obj_run, 0);
#endif
#ifdef CID_GD_CALL
  io_eff(CID_GD_CALL, gd_call_run, 0);
#endif
#ifdef CID_GD_KIND
  io_eff(CID_GD_KIND, gd_kind_run, 0);
#endif
#ifdef CID_GD_POP
  io_eff(CID_GD_POP, gd_pop_run, 0);
#endif
#ifdef CID_GD_POP_BOOL
  io_eff(CID_GD_POP_BOOL, gd_pop_bool_run, 0);
#endif
#ifdef CID_GD_POP_INT
  io_eff(CID_GD_POP_INT, gd_pop_int_run, 0);
#endif
#ifdef CID_GD_POP_FLOAT
  io_eff(CID_GD_POP_FLOAT, gd_pop_float_run, 0);
#endif
#ifdef CID_GD_POP_STR
  io_eff(CID_GD_POP_STR, gd_pop_str_run, 0);
#endif
#ifdef CID_GD_POP_VEC2
  io_eff(CID_GD_POP_VEC2, gd_pop_vec2_run, 0);
#endif
#ifdef CID_GD_POP_OBJ
  io_eff(CID_GD_POP_OBJ, gd_pop_obj_run, 0);
#endif
}

// BendRuntime
// -----------

// The node that hosts the program: _ready boots Bend and runs main up to
// its first gd.frame, _process resumes it once per frame.
static GDExtensionObjectPtr gd_rt_create(void* data, GDExtensionBool notify) {
  GDExtensionObjectPtr o = gd_construct(&gd_n_node);
  gd_set_instance(o, &gd_n_runtime, o);
  if (notify) {
    // NOTIFICATION_POSTINITIALIZE, which construct_object2 leaves to us.
    GdName  method = gd_name("notification");
    int64_t what   = 0;
    GdVar   self;
    GdVar   arg;
    GdVar   ret;
    GDExtensionCallError err = { 0 };
    gd_from[GD_OBJ](&self, &o);
    gd_from[GD_INT](&arg, &what);
    GDExtensionConstVariantPtr args[1] = { &arg };
    gd_var_call(&self, &method, args, 1, &ret, &err);
    gd_var_free(&ret);
    gd_var_free(&arg);
    gd_var_free(&self);
  }
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

// A GDExtension class also runs inside the editor, when its scene is
// open. The program must not: it would move the scene being edited.
static bool gd_in_editor(void) {
  GdName engine = gd_name("Engine");
  GdName method = gd_name("is_editor_hint");
  GDExtensionObjectPtr o = gd_global(&engine);
  GdVar self;
  GdVar ret;
  GDExtensionCallError err = { 0 };
  GDExtensionBool hint = 0;
  gd_from[GD_OBJ](&self, &o);
  gd_var_call(&self, &method, NULL, 0, &ret, &err);
  gd_into[GD_BOOL](&hint, &ret);
  gd_var_free(&ret);
  gd_var_free(&self);
  return hint != 0;
}

static void gd_rt_call(GDExtensionClassInstancePtr self,
  GDExtensionConstStringNamePtr name, void* which,
  const GDExtensionConstTypePtr* args, GDExtensionTypePtr ret) {
  if (which == &gd_n_ready) {
    if (!gd_up && !gd_in_editor()) {
      gd_self = (GDExtensionObjectPtr)self;
      gd_boot();
    }
    return;
  }
  if (gd_waiter == NULL || gd_code >= 0) {
    return;
  }
  IoAct* a  = gd_waiter;
  gd_waiter = NULL;
  a->item   = f32_rewrap((f32)*(const double*)args[0]);
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

// Lets go of what the program still held, so Godot sees no leaked texture
// or node at exit.
static void gd_level_exit(void* data, GDExtensionInitializationLevel level) {
  if (level != GDEXTENSION_INITIALIZATION_SCENE) {
    return;
  }
  for (u32 s = 1; s < gd_rows_len; s += 1) {
    gd_var_free(&gd_rows[s].var);
  }
  while (gd_sp > 0) {
    gd_var_free(gd_top());
  }
  gd_rows_len = 1;
  // Godot must not find the class once this level is gone.
  ((GDExtensionInterfaceClassdbUnregisterExtensionClass)
    ((GDExtensionInterfaceGetProcAddress)data)(
    "classdb_unregister_extension_class"))(gd_lib, &gd_n_runtime);
}

__attribute__((visibility("default")))
GDExtensionBool godot_bend_init(GDExtensionInterfaceGetProcAddress get,
  GDExtensionClassLibraryPtr lib, GDExtensionInitialization* init) {
  gd_lib          = lib;
  gd_sn_new       = (GDExtensionInterfaceStringNameNewWithLatin1Chars)
    get("string_name_new_with_latin1_chars");
  gd_sn_utf8      = (GDExtensionInterfaceStringNameNewWithUtf8CharsAndLen)
    get("string_name_new_with_utf8_chars_and_len");
  gd_str_new      = (GDExtensionInterfaceStringNewWithUtf8CharsAndLen)
    get("string_new_with_utf8_chars_and_len");
  gd_str_utf8     = (GDExtensionInterfaceStringToUtf8Chars)
    get("string_to_utf8_chars");
  gd_var_nil      = (GDExtensionInterfaceVariantNewNil)
    get("variant_new_nil");
  gd_var_copy     = (GDExtensionInterfaceVariantNewCopy)
    get("variant_new_copy");
  gd_var_free     = (GDExtensionInterfaceVariantDestroy)
    get("variant_destroy");
  gd_var_call     = (GDExtensionInterfaceVariantCall)
    get("variant_call");
  gd_var_type     = (GDExtensionInterfaceVariantGetType)
    get("variant_get_type");
  gd_var_text     = (GDExtensionInterfaceVariantStringify)
    get("variant_stringify");
  gd_construct    = (GDExtensionInterfaceClassdbConstructObject2)
    get("classdb_construct_object2");
  gd_set_instance = (GDExtensionInterfaceObjectSetInstance)
    get("object_set_instance");
  gd_obj_id       = (GDExtensionInterfaceObjectGetInstanceId)
    get("object_get_instance_id");
  gd_obj_at       = (GDExtensionInterfaceObjectGetInstanceFromId)
    get("object_get_instance_from_id");
  gd_global       = (GDExtensionInterfaceGlobalGetSingleton)
    get("global_get_singleton");
  GDExtensionInterfaceGetVariantFromTypeConstructor from =
    (GDExtensionInterfaceGetVariantFromTypeConstructor)
    get("get_variant_from_type_constructor");
  GDExtensionInterfaceGetVariantToTypeConstructor into =
    (GDExtensionInterfaceGetVariantToTypeConstructor)
    get("get_variant_to_type_constructor");
  for (int k = 0; k < GD_KINDS; k += 1) {
    gd_from[k] = from(gd_types[k]);
    gd_into[k] = into(gd_types[k]);
  }
  GDExtensionInterfaceVariantGetPtrDestructor destructor =
    (GDExtensionInterfaceVariantGetPtrDestructor)
    get("variant_get_ptr_destructor");
  gd_str_free = destructor(GDEXTENSION_VARIANT_TYPE_STRING);
  gd_sn_free  = destructor(GDEXTENSION_VARIANT_TYPE_STRING_NAME);
  gd_n_node    = gd_name("Node");
  gd_n_runtime = gd_name("BendRuntime");
  gd_n_ready   = gd_name("_ready");
  gd_n_process = gd_name("_process");
  GDExtensionInterfaceVariantGetPtrUtilityFunction util =
    (GDExtensionInterfaceVariantGetPtrUtilityFunction)
    get("variant_get_ptr_utility_function");
  GdName print  = gd_name("print");
  GdName error  = gd_name("push_error");
  gd_util_print = util(&print, 2648703342);
  gd_util_error = util(&error, 2648703342);
  init->minimum_initialization_level = GDEXTENSION_INITIALIZATION_SCENE;
  init->userdata     = (void*)get;
  init->initialize   = gd_level_init;
  init->deinitialize = gd_level_exit;
  return 1;
}
