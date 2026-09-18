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
static GDExtensionInterfaceVariantConstruct             gd_var_make;
static GDExtensionInterfaceVariantGetType               gd_var_type;
static GDExtensionInterfaceVariantStringify             gd_var_text;
static GDExtensionInterfaceClassdbConstructObject2      gd_construct;
static GDExtensionInterfaceObjectSetInstance            gd_set_instance;
static GDExtensionInterfaceObjectGetInstanceId          gd_obj_id;
static GDExtensionInterfaceObjectGetInstanceFromId      gd_obj_at;
static GDExtensionInterfaceGlobalGetSingleton           gd_global;
static GDExtensionInterfaceCallableCustomCreate2        gd_callable;
static GDExtensionInterfaceRefGetObject                 gd_ref_obj;
static GDExtensionInterfaceClassdbGetMethodBind         gd_bind;
static GDExtensionInterfaceObjectMethodBindCall         gd_bind_call;
static GDExtensionInterfaceVariantGetPtrUtilityFunction gd_util;
static GDExtensionPtrDestructor                         gd_str_free;
static GDExtensionPtrDestructor                         gd_sn_free;
static GDExtensionPtrDestructor                         gd_call_free;
static GDExtensionPtrUtilityFunction                    gd_util_print;
static GDExtensionPtrUtilityFunction                    gd_util_error;

// A StringName, a String and a Variant, as opaque storage of their size
// (a Variant is 24 bytes in a single-precision build, the official one).
typedef struct { void* p; }  GdName;
typedef struct { void* p; }  GdStr;
typedef struct { u64 w[3]; } GdVar;
typedef struct { f32 x, y; }       GdVec2;
typedef struct { f32 x, y, z; }    GdVec3;
typedef struct { f32 r, g, b, a; } GdColor;
typedef struct { u64 w[2]; } GdCall;

// The kinds this binding carries, and Godot's constructors between each
// and a Variant.
enum {
  GD_BOOL, GD_INT, GD_FLOAT, GD_STR, GD_VEC2, GD_OBJ, GD_CALL, GD_VEC3,
  GD_COLOR, GD_KINDS
};

static const GDExtensionVariantType gd_types[GD_KINDS] = {
  GDEXTENSION_VARIANT_TYPE_BOOL,    GDEXTENSION_VARIANT_TYPE_INT,
  GDEXTENSION_VARIANT_TYPE_FLOAT,   GDEXTENSION_VARIANT_TYPE_STRING,
  GDEXTENSION_VARIANT_TYPE_VECTOR2, GDEXTENSION_VARIANT_TYPE_OBJECT,
  GDEXTENSION_VARIANT_TYPE_CALLABLE, GDEXTENSION_VARIANT_TYPE_VECTOR3,
  GDEXTENSION_VARIANT_TYPE_COLOR,
};

static GDExtensionVariantFromTypeConstructorFunc gd_from[GD_KINDS];
static GDExtensionTypeFromVariantConstructorFunc gd_into[GD_KINDS];

static GdName gd_n_node;
static GdName gd_n_runtime;
static GdName gd_n_ready;
static GdName gd_n_process;
static GdName gd_n_input;

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

// classdb_construct_object2 leaves NOTIFICATION_POSTINITIALIZE (0) to the
// caller. A Node2D gets by without it; a Control crashes on first use.
static void gd_postinit(GDExtensionObjectPtr o) {
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
  gd_sn_free(&method);
}

// Objects
// -------

// A Bend Object is a handle into this table: a row in the low 20 bits, the
// row's generation above them. A row keeps the instance id, the test that
// the object still lives, and a Variant of it, which holds a RefCounted (a
// texture, any Resource) alive while the program may name it. Rows are
// found again by id, so an object met every frame keeps one handle.
// Godot.drop frees a row; the next object to take it gets a new generation,
// so a handle kept past its drop names nothing, never the newcomer.
// Handle 0 is null.
#define GD_ROW_BITS 20
#define GD_ROW_MASK ((1u << GD_ROW_BITS) - 1)
#define GD_TOMB     (~0u)

typedef struct {
  u64   id;   // 0 when the row is free
  u32   gen;
  u32   next; // the free list
  GdVar var;
} GdRow;

static GdRow* gd_rows;
static u32    gd_rows_len = 1;
static u32    gd_rows_cap;
static u32    gd_rows_free;
static u32*   gd_index;     // open addressing, id -> row; 0 empty, GD_TOMB
static u32    gd_index_cap;
static u32    gd_index_used;

static u32 gd_index_at(u64 id) {
  return (u32)(id * 0x9E3779B97F4A7C15ull >> 32) & (gd_index_cap - 1);
}

static void gd_index_put(u64 id, u32 row) {
  u32 i = gd_index_at(id);
  while (gd_index[i] != 0 && gd_index[i] != GD_TOMB) {
    i = (i + 1) & (gd_index_cap - 1);
  }
  gd_index_used += gd_index[i] == 0;
  gd_index[i] = row;
}

// The slot of the index that holds id's row, or -1.
static int64_t gd_index_find(u64 id) {
  if (gd_index_cap == 0) {
    return -1;
  }
  for (u32 i = gd_index_at(id); gd_index[i] != 0;
    i = (i + 1) & (gd_index_cap - 1)) {
    if (gd_index[i] != GD_TOMB && gd_rows[gd_index[i]].id == id) {
      return i;
    }
  }
  return -1;
}

#define gd_handle(row) ((gd_rows[row].gen << GD_ROW_BITS) | (row))

static u32 gd_slot_of(const GdVar* v) {
  GDExtensionObjectPtr o = NULL;
  gd_into[GD_OBJ](&o, (GDExtensionVariantPtr)v);
  if (o == NULL) {
    return 0;
  }
  u64     id = gd_obj_id(o);
  int64_t at = gd_index_find(id);
  if (at >= 0) {
    return gd_handle(gd_index[at]);
  }
  if (2 * (gd_index_used + 1) >= gd_index_cap) {
    gd_index_cap  = gd_index_cap == 0 ? 256 : 2 * gd_index_cap;
    gd_index_used = 0;
    free(gd_index);
    gd_index = io_mem(calloc(gd_index_cap, sizeof(u32)));
    for (u32 r = 1; r < gd_rows_len; r += 1) {
      if (gd_rows[r].id != 0) {
        gd_index_put(gd_rows[r].id, r);
      }
    }
  }
  u32 row = gd_rows_free;
  if (row != 0) {
    gd_rows_free = gd_rows[row].next;
  } else {
    if (gd_rows_len > GD_ROW_MASK) {
      err_fail("godot: more than 1048575 objects held at once; drop some");
    }
    if (gd_rows_len >= gd_rows_cap) {
      gd_rows_cap = gd_rows_cap == 0 ? 64 : 2 * gd_rows_cap;
      gd_rows     = io_mem(realloc(gd_rows, gd_rows_cap * sizeof(GdRow)));
    }
    row = gd_rows_len;
    gd_rows_len += 1;
    gd_rows[row].gen = 0;
  }
  gd_rows[row].id = id;
  gd_var_copy(&gd_rows[row].var, (GDExtensionConstVariantPtr)v);
  gd_index_put(id, row);
  return gd_handle(row);
}

static u32 gd_slot_new(GDExtensionObjectPtr o) {
  GdVar v;
  gd_from[GD_OBJ](&v, &o);
  u32 slot = gd_slot_of(&v);
  gd_var_free(&v);
  return slot;
}

// The handle's row, or 0 for null, a dropped handle, or a bad one.
static u32 gd_slot_row(u32 handle) {
  u32 row = handle & GD_ROW_MASK;
  return row != 0 && row < gd_rows_len && gd_rows[row].id != 0
    && gd_rows[row].gen == handle >> GD_ROW_BITS ? row : 0;
}

// The handle's Variant, or NULL when it names nothing or a freed object.
static GdVar* gd_slot_var(u32 handle) {
  u32 row = gd_slot_row(handle);
  return row == 0 || gd_obj_at(gd_rows[row].id) == NULL
    ? NULL : &gd_rows[row].var;
}

static void gd_slot_drop(u32 handle) {
  u32 row = gd_slot_row(handle);
  if (row == 0) {
    return;
  }
  gd_index[gd_index_find(gd_rows[row].id)] = GD_TOMB;
  gd_var_free(&gd_rows[row].var);
  gd_rows[row].id   = 0;
  gd_rows[row].gen  = (gd_rows[row].gen + 1) & ((1u << (32 - GD_ROW_BITS)) - 1);
  gd_rows[row].next = gd_rows_free;
  gd_rows_free      = row;
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

// io_wait without the wait: the runtime's own poller sleeps until a parked
// computation is due (a sleep's time, a socket's readiness, a finished
// blocking job), and Godot's thread cannot sleep. This asks the same
// questions with a zero timeout and readies whatever is due now. It
// follows io_wait line by line, so a Bend bump may need it looked at.
static void gd_poll(Env e) {
  struct pollfd* fds = io_mem(malloc((io_live + 1) * sizeof *fds));
  u32 n = 1;
  fds[0].fd     = io_wake_fd[0];
  fds[0].events = POLLIN;
  for (IoAct* a = io_park.head; a != NULL; a = a->next) {
    if (a->time == 0) {
      fds[n].fd     = (int)a->work.word;
      fds[n].events = a->evts;
      n += 1;
    }
  }
  while (poll(fds, n, 0) < 0) {
    if (errno != EINTR) {
      err_fail("the poller failed");
    }
  }
  if (fds[0].revents != 0) {
    io_take(e);
  }
  u64   now  = io_tick();
  u32   i    = 1;
  IoQue todo = io_park;
  io_park.head = NULL;
  io_park.last = NULL;
  while (todo.head != NULL) {
    IoAct* a   = io_pop(&todo);
    bool   due = a->time == 0 ? fds[i].revents != 0 : a->time <= now;
    i += a->time == 0;
    if (!due) {
      io_push(&io_park, a);
      continue;
    }
    Term x = a->work.pack(e, &a->work);
    if (x != IO_PARK) {
      a->item = x;
      io_push(&io_runs, a);
    }
  }
  free(fds);
}

// Runs every ready computation up to its next parked effect, then readies
// the parked ones that came due and runs those. The native io_loop blocks
// when nothing is ready; here that hands the thread back to Godot, and
// the next frame asks again.
static void gd_pump(void) {
  Env e = { CORPUS, ALC[0] };
  for (;;) {
    while (gd_code < 0 && io_runs.head != NULL) {
      gd_code = io_step(e, io_pop(&io_runs));
    }
    if (gd_code >= 0 || (io_park.head == NULL && io_busy == 0)) {
      break;
    }
    gd_poll(e);
    if (io_runs.head == NULL) {
      break;
    }
  }
  io_sync();
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

// Signals
// -------

// Godot calls a connected signal whenever it fires, often from inside a
// gd.call the program is still in, and Bend cannot be entered twice. So
// the Callable a connect makes only queues what it heard, the program's
// tag and a copy of the arguments, and the program takes the queue when
// it next asks (Godot.signals), in the order the signals fired.
typedef struct {
  u32    tag;
  u32    argc;
  GdVar* args;
} GdEvent;

static GdEvent* gd_events;
static u32      gd_events_head;
static u32      gd_events_len;
static u32      gd_events_cap;

static void gd_signal_call(void* data, const GDExtensionConstVariantPtr* args,
  GDExtensionInt argc, GDExtensionVariantPtr ret, GDExtensionCallError* err) {
  if (gd_events_head == gd_events_len) {
    gd_events_head = 0;
    gd_events_len  = 0;
  }
  if (gd_events_len == gd_events_cap) {
    gd_events_cap = gd_events_cap == 0 ? 32 : 2 * gd_events_cap;
    gd_events     = io_mem(realloc(gd_events, gd_events_cap * sizeof(GdEvent)));
  }
  GdEvent* ev = &gd_events[gd_events_len];
  gd_events_len += 1;
  ev->tag  = (u32)(uintptr_t)data;
  ev->argc = (u32)argc;
  ev->args = argc == 0 ? NULL : io_mem(malloc((size_t)argc * sizeof(GdVar)));
  for (u32 i = 0; i < ev->argc; i += 1) {
    gd_var_copy(&ev->args[i], args[i]);
  }
  err->error = GDEXTENSION_CALL_OK;
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
  u32 slot = 0;
  if (o == NULL) {
    gd_error("no class to instantiate named ", text);
  } else {
    // The handle first: its Variant is a RefCounted's first reference, and
    // the one gd_postinit takes and lets go would otherwise free it.
    slot = gd_slot_new(o);
    gd_postinit(o);
  }
  gd_sn_free(&name);
  free(text);
  return (Term)slot;
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
  int64_t v = (int32_t)(u32)f[0];
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

Term gd_push_vec3_run(Env e, Term* f, IoWork* w) {
  GdVec3 v = { f32_unbox(f[0]), f32_unbox(f[1]), f32_unbox(f[2]) };
  gd_from[GD_VEC3](gd_push(), &v);
  return GD_UNIT;
}

Term gd_push_color_run(Env e, Term* f, IoWork* w) {
  GdColor v = { f32_unbox(f[0]), f32_unbox(f[1]), f32_unbox(f[2]),
    f32_unbox(f[3]) };
  gd_from[GD_COLOR](gd_push(), &v);
  return GD_UNIT;
}

// A method of a Variant by name, for the few the arrays need. The result
// is the caller's to free.
static void gd_method(GdVar* self, const char* method, GdVar* arg,
  GdVar* ret) {
  GdName name = gd_name(method);
  GDExtensionCallError err = { 0 };
  GDExtensionConstVariantPtr args[1] = { arg };
  gd_var_call(self, &name, args, arg == NULL ? 0 : 1, ret, &err);
  gd_sn_free(&name);
}

// gd.array_new folds the top n values, pushed first to last, into one
// Array.
Term gd_array_new_run(Env e, Term* f, IoWork* w) {
  u32 n = (u32)f[0];
  if (n > gd_sp) {
    err_fail("godot: an array of more items than the stack holds");
  }
  GdVar  arr;
  GdVar* items = gd_stack + (gd_sp - n);
  GDExtensionCallError err = { 0 };
  gd_var_make(GDEXTENSION_VARIANT_TYPE_ARRAY, &arr, NULL, 0, &err);
  for (u32 i = 0; i < n; i += 1) {
    GdVar ret;
    gd_method(&arr, "push_back", &items[i], &ret);
    gd_var_free(&ret);
    gd_var_free(&items[i]);
  }
  gd_sp -= n;
  *gd_push() = arr;
  return GD_UNIT;
}

// gd.array_open is its inverse: the items go on the stack first to last,
// and the answer is how many.
Term gd_array_open_run(Env e, Term* f, IoWork* w) {
  GdVar   arr = *gd_top();
  GdVar   ret;
  int64_t n = 0;
  gd_method(&arr, "size", NULL, &ret);
  gd_into[GD_INT](&n, &ret);
  gd_var_free(&ret);
  for (int64_t i = 0; i < n; i += 1) {
    GdVar at;
    GdVar item;
    gd_from[GD_INT](&at, &i);
    gd_method(&arr, "get", &at, &item);
    gd_var_free(&at);
    *gd_push() = item;
  }
  gd_var_free(&arr);
  return (Term)(u32)n;
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

// gd.static calls a class's static method: the arguments are the top argc
// values, and the result replaces them, as in gd.call. The hash is the
// method's, from extension_api.json, which is how Godot finds the bind.
Term gd_static_run(Env e, Term* f, IoWork* w) {
  uint64_t cn = 0;
  uint64_t mn = 0;
  char*  cls    = io_cstr(e, f[0], &cn);
  char*  method = io_cstr(e, f[1], &mn);
  u32    argc   = (u32)f[3];
  if (argc > gd_sp) {
    err_fail("godot: a call with more arguments than the stack holds");
  }
  GdVar* args = gd_stack + (gd_sp - argc);
  GdVar  ret;
  GdName cname;
  GdName mname;
  gd_sn_utf8(&cname, cls, (GDExtensionInt)cn);
  gd_sn_utf8(&mname, method, (GDExtensionInt)mn);
  GDExtensionMethodBindPtr bind = gd_bind(&cname, &mname, (u32)f[2]);
  if (bind == NULL) {
    gd_error("no such static method: ", method);
    gd_var_nil(&ret);
  } else {
    GDExtensionConstVariantPtr ptrs[argc + 1];
    for (u32 i = 0; i < argc; i += 1) {
      ptrs[i] = &args[i];
    }
    GDExtensionCallError err = { 0 };
    gd_bind_call(bind, NULL, ptrs, argc, &ret, &err);
    if (err.error != GDEXTENSION_CALL_OK) {
      gd_error("a static call with bad arguments: ", method);
    }
  }
  for (u32 i = 0; i < argc; i += 1) {
    gd_var_free(&args[i]);
  }
  gd_sp -= argc;
  *gd_push() = ret;
  gd_sn_free(&mname);
  gd_sn_free(&cname);
  free(method);
  free(cls);
  return GD_UNIT;
}

// gd.util calls a utility function (randf, lerp, ..). Those have no call
// by Variant, only one by typed pointers, so sig spells the types: a
// letter per argument, '>', and the answer's, of f float, i int, b bool,
// s String, v Variant, o Object and - nothing. The arguments are the top
// values, and the result replaces them.
Term gd_util_run(Env e, Term* f, IoWork* w) {
  uint64_t nn = 0;
  uint64_t sn = 0;
  char* name = io_cstr(e, f[0], &nn);
  char* sig  = io_cstr(e, f[2], &sn);
  u32   argc = (u32)(strchr(sig, '>') - sig);
  if (argc > gd_sp || argc > 8) {
    err_fail("godot: a utility call the stack cannot serve");
  }
  GdName uname;
  gd_sn_utf8(&uname, name, (GDExtensionInt)nn);
  GDExtensionPtrUtilityFunction fn = gd_util(&uname, (u32)f[1]);
  GdVar* args = gd_stack + (gd_sp - argc);
  GdVar  ret;
  gd_var_nil(&ret);
  if (fn == NULL) {
    gd_error("no such utility function: ", name);
  } else {
    union { double f; int64_t i; GDExtensionBool b; GdStr s; } at[8];
    GDExtensionConstTypePtr ptrs[8];
    for (u32 i = 0; i < argc; i += 1) {
      ptrs[i] = &at[i];
      switch (sig[i]) {
        case 'f': gd_into[GD_FLOAT](&at[i].f, &args[i]); break;
        case 'i': gd_into[GD_INT](&at[i].i, &args[i]);   break;
        case 'b': gd_into[GD_BOOL](&at[i].b, &args[i]);  break;
        case 's': gd_into[GD_STR](&at[i].s, &args[i]);   break;
        default:  ptrs[i] = &args[i];                    break;
      }
    }
    union { double f; int64_t i; GDExtensionBool b; GdStr s;
      GDExtensionObjectPtr o; GdVar v; } out = { 0 };
    char kind = sig[argc + 1];
    fn(kind == '-' ? NULL : (void*)&out, ptrs, (int)argc);
    switch (kind) {
      case 'f': gd_from[GD_FLOAT](&ret, &out.f); break;
      case 'i': gd_from[GD_INT](&ret, &out.i);   break;
      case 'b': gd_from[GD_BOOL](&ret, &out.b);  break;
      case 's': gd_from[GD_STR](&ret, &out.s); gd_str_free(&out.s); break;
      case 'o': gd_from[GD_OBJ](&ret, &out.o);   break;
      case 'v': ret = out.v;                     break;
      default:                                   break;
    }
    for (u32 i = 0; i < argc; i += 1) {
      if (sig[i] == 's') {
        gd_str_free(&at[i].s);
      }
    }
  }
  for (u32 i = 0; i < argc; i += 1) {
    gd_var_free(&args[i]);
  }
  gd_sp -= argc;
  *gd_push() = ret;
  gd_sn_free(&uname);
  free(sig);
  free(name);
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
    case GDEXTENSION_VARIANT_TYPE_VECTOR3:     return 7;
    case GDEXTENSION_VARIANT_TYPE_COLOR:       return 8;
    case GDEXTENSION_VARIANT_TYPE_ARRAY:       return 9;
    default:                                   return 10;
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

Term gd_pop_vec3_run(Env e, Term* f, IoWork* w) {
  GdVar* v = gd_top();
  GdVec3 p = { 0, 0, 0 };
  gd_into[GD_VEC3](&p, v);
  gd_var_free(v);
  return io_tup(e, f32_rewrap(p.x),
    io_tup(e, f32_rewrap(p.y), f32_rewrap(p.z)));
}

Term gd_pop_color_run(Env e, Term* f, IoWork* w) {
  GdVar*  v = gd_top();
  GdColor c = { 0, 0, 0, 0 };
  gd_into[GD_COLOR](&c, v);
  gd_var_free(v);
  return io_tup(e, f32_rewrap(c.r), io_tup(e, f32_rewrap(c.g),
    io_tup(e, f32_rewrap(c.b), f32_rewrap(c.a))));
}

Term gd_pop_obj_run(Env e, Term* f, IoWork* w) {
  GdVar* v = gd_top();
  u32 slot = gd_slot_of(v);
  gd_var_free(v);
  return (Term)slot;
}

Term gd_drop_run(Env e, Term* f, IoWork* w) {
  gd_slot_drop((u32)f[0]);
  return GD_UNIT;
}

// gd.listen turns the input events on or off; off is the default, since a
// program that never takes its signals would only grow the queue.
static bool gd_listening;

Term gd_listen_run(Env e, Term* f, IoWork* w) {
  gd_listening = (u32)f[0] != 0;
  return GD_UNIT;
}

// gd.connect joins a signal to the queue under the program's tag. The
// Callable belongs to the BendRuntime node, so Godot drops the connection
// with it.
Term gd_connect_run(Env e, Term* f, IoWork* w) {
  uint64_t n = 0;
  GdVar* self = gd_slot_var((u32)f[0]);
  char*  text = io_cstr(e, f[1], &n);
  if (self == NULL) {
    gd_error("a connect on null or on a freed object: ", text);
  } else {
    GDExtensionCallableCustomInfo2 info = {
      .callable_userdata = (void*)(uintptr_t)(u32)f[2],
      .token             = gd_lib,
      .object_id         = gd_obj_id(gd_self),
      .call_func         = gd_signal_call,
    };
    GdCall call;
    GdStr  name;
    GdVar  args[2];
    GdVar  ret;
    GdName method = gd_name("connect");
    GDExtensionCallError err = { 0 };
    gd_callable(&call, &info);
    gd_str_new(&name, text, (GDExtensionInt)n);
    gd_from[GD_STR](&args[0], &name);
    gd_from[GD_CALL](&args[1], &call);
    GDExtensionConstVariantPtr ptrs[2] = { &args[0], &args[1] };
    gd_var_call(self, &method, ptrs, 2, &ret, &err);
    int64_t code = 0;
    gd_into[GD_INT](&code, &ret);
    if (err.error != GDEXTENSION_CALL_OK || code != 0) {
      gd_error("no signal to connect named ", text);
    }
    gd_var_free(&ret);
    gd_var_free(&args[1]);
    gd_var_free(&args[0]);
    gd_str_free(&name);
    gd_sn_free(&method);
    gd_call_free(&call);
  }
  free(text);
  return GD_UNIT;
}

// gd.events counts the queue.
Term gd_events_run(Env e, Term* f, IoWork* w) {
  return (Term)(gd_events_len - gd_events_head);
}

// gd.event takes the oldest: its arguments go on the stack, first to
// last, then their count, and the answer is the tag.
Term gd_event_run(Env e, Term* f, IoWork* w) {
  if (gd_events_head == gd_events_len) {
    err_fail("godot: an event taken from an empty queue");
  }
  GdEvent ev = gd_events[gd_events_head];
  gd_events_head += 1;
  for (u32 i = 0; i < ev.argc; i += 1) {
    *gd_push() = ev.args[i];
  }
  free(ev.args);
  int64_t argc = ev.argc;
  gd_from[GD_INT](gd_push(), &argc);
  return (Term)ev.tag;
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
#ifdef CID_GD_PUSH_VEC3
  io_eff(CID_GD_PUSH_VEC3, gd_push_vec3_run, 0);
#endif
#ifdef CID_GD_PUSH_COLOR
  io_eff(CID_GD_PUSH_COLOR, gd_push_color_run, 0);
#endif
#ifdef CID_GD_ARRAY_NEW
  io_eff(CID_GD_ARRAY_NEW, gd_array_new_run, 0);
#endif
#ifdef CID_GD_ARRAY_OPEN
  io_eff(CID_GD_ARRAY_OPEN, gd_array_open_run, 0);
#endif
#ifdef CID_GD_POP_VEC3
  io_eff(CID_GD_POP_VEC3, gd_pop_vec3_run, 0);
#endif
#ifdef CID_GD_POP_COLOR
  io_eff(CID_GD_POP_COLOR, gd_pop_color_run, 0);
#endif
#ifdef CID_GD_DROP
  io_eff(CID_GD_DROP, gd_drop_run, 0);
#endif
#ifdef CID_GD_LISTEN
  io_eff(CID_GD_LISTEN, gd_listen_run, 0);
#endif
#ifdef CID_GD_STATIC
  io_eff(CID_GD_STATIC, gd_static_run, 0);
#endif
#ifdef CID_GD_UTIL
  io_eff(CID_GD_UTIL, gd_util_run, 0);
#endif
#ifdef CID_GD_CONNECT
  io_eff(CID_GD_CONNECT, gd_connect_run, 0);
#endif
#ifdef CID_GD_EVENTS
  io_eff(CID_GD_EVENTS, gd_events_run, 0);
#endif
#ifdef CID_GD_EVENT
  io_eff(CID_GD_EVENT, gd_event_run, 0);
#endif
#ifdef CID_GD_POP_OBJ
  io_eff(CID_GD_POP_OBJ, gd_pop_obj_run, 0);
#endif
}

// Input
// -----

// An input event joins the signal queue already taken apart, as values
// under a reserved tag, so no InputEvent handle is made for the program to
// drop: 4294967295 a key (keycode, pressed, echo), 4294967294 a mouse
// button (index, pressed, position), 4294967293 a mouse move (position,
// relative).
static void gd_input(GDExtensionObjectPtr event) {
  static const struct { const char* cls; u32 tag; const char* get[3]; }
  kinds[3] = {
    { "InputEventKey",         4294967295u,
      { "get_keycode", "is_pressed", "is_echo" } },
    { "InputEventMouseButton", 4294967294u,
      { "get_button_index", "is_pressed", "get_position" } },
    { "InputEventMouseMotion", 4294967293u,
      { "get_position", "get_relative", NULL } },
  };
  GdVar self;
  gd_from[GD_OBJ](&self, &event);
  for (int k = 0; k < 3; k += 1) {
    GdStr cls;
    GdVar arg;
    GdVar is;
    GDExtensionBool yes = 0;
    gd_str_new(&cls, kinds[k].cls, (GDExtensionInt)strlen(kinds[k].cls));
    gd_from[GD_STR](&arg, &cls);
    gd_method(&self, "is_class", &arg, &is);
    gd_into[GD_BOOL](&yes, &is);
    gd_var_free(&is);
    gd_var_free(&arg);
    gd_str_free(&cls);
    if (!yes) {
      continue;
    }
    GdVar vals[3];
    GDExtensionConstVariantPtr ptrs[3];
    u32 n = 0;
    for (; n < 3 && kinds[k].get[n] != NULL; n += 1) {
      gd_method(&self, kinds[k].get[n], NULL, &vals[n]);
      ptrs[n] = &vals[n];
    }
    GDExtensionCallError err = { 0 };
    gd_signal_call((void*)(uintptr_t)kinds[k].tag, ptrs, n, NULL, &err);
    for (u32 i = 0; i < n; i += 1) {
      gd_var_free(&vals[i]);
    }
    break;
  }
  gd_var_free(&self);
}

// BendRuntime
// -----------

// The node that hosts the program: _ready boots Bend and runs main up to
// its first gd.frame, _process resumes it once per frame.
static GDExtensionObjectPtr gd_rt_create(void* data, GDExtensionBool notify) {
  GDExtensionObjectPtr o = gd_construct(&gd_n_node);
  gd_set_instance(o, &gd_n_runtime, o);
  if (notify) {
    gd_postinit(o);
  }
  return o;
}

static void gd_rt_free(void* data, GDExtensionClassInstancePtr self) {
}

static void* gd_rt_virtual(void* data, GDExtensionConstStringNamePtr name,
  uint32_t hash) {
  void* p = ((const GdName*)name)->p;
  return p == gd_n_ready.p ? &gd_n_ready : p == gd_n_process.p
    ? &gd_n_process : p == gd_n_input.p ? &gd_n_input : NULL;
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
  if (which == &gd_n_input) {
    if (gd_up && gd_listening && gd_code < 0) {
      gd_input(gd_ref_obj(args[0]));
    }
    return;
  }
  if (!gd_up || gd_code >= 0) {
    return;
  }
  // A frame: answer whoever waits on gd.frame, and pump either way, since
  // a program may be parked on a sleep or a socket instead.
  if (gd_waiter != NULL) {
    IoAct* a  = gd_waiter;
    gd_waiter = NULL;
    a->item   = f32_rewrap((f32)*(const double*)args[0]);
    io_push(&io_runs, a);
  }
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
    if (gd_rows[s].id != 0) {
      gd_var_free(&gd_rows[s].var);
    }
  }
  while (gd_sp > 0) {
    gd_var_free(gd_top());
  }
  for (; gd_events_head < gd_events_len; gd_events_head += 1) {
    GdEvent* ev = &gd_events[gd_events_head];
    for (u32 i = 0; i < ev->argc; i += 1) {
      gd_var_free(&ev->args[i]);
    }
    free(ev->args);
  }
  gd_rows_len  = 1;
  gd_rows_free = 0;
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
  gd_var_make     = (GDExtensionInterfaceVariantConstruct)
    get("variant_construct");
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
  gd_bind         = (GDExtensionInterfaceClassdbGetMethodBind)
    get("classdb_get_method_bind");
  gd_bind_call    = (GDExtensionInterfaceObjectMethodBindCall)
    get("object_method_bind_call");
  gd_ref_obj      = (GDExtensionInterfaceRefGetObject)
    get("ref_get_object");
  gd_callable     = (GDExtensionInterfaceCallableCustomCreate2)
    get("callable_custom_create2");
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
  gd_call_free = destructor(GDEXTENSION_VARIANT_TYPE_CALLABLE);
  gd_n_node    = gd_name("Node");
  gd_n_runtime = gd_name("BendRuntime");
  gd_n_ready   = gd_name("_ready");
  gd_n_process = gd_name("_process");
  gd_n_input   = gd_name("_input");
  GDExtensionInterfaceVariantGetPtrUtilityFunction util = gd_util =
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
