# Godot
# =====

# Bend bindings for the Godot engine. Import this file as Godot:
#
#   import ../godot/Godot.bend as Godot
#
# The gd.* defs are the raw effects, filled by godot.c; their names are
# what the C side sees (gd.print is CID_GD_PRINT and gd_print_run), and an
# import alias does not reach them, hence the prefix. The defs below them
# are the API a program uses, so a program writes Godot.print.
import Base

# An object of the engine. The slot names a row of godot.c's table of
# instance ids, never a pointer: a handle is plain Data, so it copies
# freely, and one whose object was freed answers Nil to every call instead
# of dangling. Slot 0 is null. The raw effects carry the bare U32.
type Object is Data:
  Obj{slot: U32}

def gd.print(text: String) -> IO(Unit):
  import "./godot.c"
  import "./godot.js"

def gd.frame() -> IO(F32):
  import "./godot.c"
  import "./godot.js"

def gd.self() -> IO(U32):
  import "./godot.c"
  import "./godot.js"

def gd.singleton(name: String) -> IO(U32):
  import "./godot.c"
  import "./godot.js"

def gd.new(class: String) -> IO(U32):
  import "./godot.c"
  import "./godot.js"

# Values cross to the engine over a stack of Godot Variants, as in Lua's C
# API: push the arguments, call (which pops them and pushes the result),
# ask the top's kind, pop it as that kind. Every effect then takes and
# answers only words, Strings and handles, the shapes Base's own effects
# use, and no datatype's memory layout is part of the contract.
def gd.push_nil() -> IO(Unit):
  import "./godot.c"
  import "./godot.js"

def gd.push_bool(v: U32) -> IO(Unit):
  import "./godot.c"
  import "./godot.js"

def gd.push_int(v: U32) -> IO(Unit):
  import "./godot.c"
  import "./godot.js"

def gd.push_float(v: F32) -> IO(Unit):
  import "./godot.c"
  import "./godot.js"

def gd.push_str(v: String) -> IO(Unit):
  import "./godot.c"
  import "./godot.js"

def gd.push_vec2(x: F32, y: F32) -> IO(Unit):
  import "./godot.c"
  import "./godot.js"

def gd.push_vec3(x: F32, y: F32, z: F32) -> IO(Unit):
  import "./godot.c"
  import "./godot.js"

def gd.push_color(r: F32, g: F32, b: F32, a: F32) -> IO(Unit):
  import "./godot.c"
  import "./godot.js"

# Pops n values, pushed first to last, and pushes the Array of them.
def gd.array_new(n: U32) -> IO(Unit):
  import "./godot.c"
  import "./godot.js"

# Pops an Array, pushes its items first to last, and answers how many.
def gd.array_open() -> IO(U32):
  import "./godot.c"
  import "./godot.js"

def gd.push_obj(slot: U32) -> IO(Unit):
  import "./godot.c"
  import "./godot.js"

def gd.call(slot: U32, method: String, argc: U32) -> IO(Unit):
  import "./godot.c"
  import "./godot.js"

# The top's kind: 0 Nil, 1 Bool, 2 Int, 3 Float, 4 String, 5 Vector2,
# 6 Object, 7 Vector3, 8 Color, 9 Array, 10 anything else.
def gd.kind() -> IO(Nat):
  import "./godot.c"
  import "./godot.js"

def gd.pop() -> IO(Unit):
  import "./godot.c"
  import "./godot.js"

def gd.pop_bool() -> IO(Bool):
  import "./godot.c"
  import "./godot.js"

def gd.pop_int() -> IO(U32):
  import "./godot.c"
  import "./godot.js"

def gd.pop_float() -> IO(F32):
  import "./godot.c"
  import "./godot.js"

def gd.pop_str() -> IO(String):
  import "./godot.c"
  import "./godot.js"

def gd.pop_vec2() -> IO(F32 & F32):
  import "./godot.c"
  import "./godot.js"

def gd.pop_vec3() -> IO(F32 & F32 & F32):
  import "./godot.c"
  import "./godot.js"

def gd.pop_color() -> IO(F32 & F32 & F32 & F32):
  import "./godot.c"
  import "./godot.js"

def gd.pop_obj() -> IO(U32):
  import "./godot.c"
  import "./godot.js"

def gd.connect(slot: U32, signal: String, tag: U32) -> IO(Unit):
  import "./godot.c"
  import "./godot.js"

# How many signals wait in the queue.
def gd.events() -> IO(Nat):
  import "./godot.c"
  import "./godot.js"

# Takes the oldest: answers its tag, and leaves on the stack its
# arguments, first to last, under their count.
def gd.event() -> IO(U32):
  import "./godot.c"
  import "./godot.js"

# Variant
# -------

# A Godot value. Bend has no signed integer, so an Int is a 32-bit window
# in two's complement: Godot's -1 arrives as 4294967295, and that goes back
# as -1. Other is a kind this binding does not carry yet (dictionaries,
# transforms, packed arrays, ..).
type Variant is Data:
  VNil{}
  VBool{v: Bool}
  VInt{v: U32}
  VFloat{v: F32}
  VStr{v: String}
  VVec2{x: F32, y: F32}
  VVec3{x: F32, y: F32, z: F32}
  VColor{r: F32, g: F32, b: F32, a: F32}
  VArr{items: List<&2, Variant>}
  VObj{v: Object}
  VOther{}

def Variant.bit(b: Bool) -> U32:
  match b:
    case True{}:
      1
    case False{}:
      0

def Object.push(obj: Object) -> IO(Unit):
  Obj{slot} = obj
  gd.push_obj(slot)

def Object.call(obj: Object, method: String, argc: U32) -> IO(Unit):
  Obj{slot} = obj
  gd.call(slot, method, argc)

# Wraps a raw effect that answers a slot.
def Object.of(raw: IO(U32)) -> IO(Object):
  do IO<Object>:
    slot : U32 <- raw
    return Obj{slot}

def Variant.vec2(p: F32 & F32) -> Variant:
  (x, y) = p
  VVec2{x, y}

def Variant.vec3(p: F32 & F32 & F32) -> Variant:
  (x, y, z) = p
  VVec3{x, y, z}

def Variant.color(p: F32 & F32 & F32 & F32) -> Variant:
  (r, g, b, a) = p
  VColor{r, g, b, a}

# Pushes every value, first to last, and answers n plus how many. An
# array's items go through the same def, since Bend has no mutual
# recursion: they are pushed, then folded into one Array.
def Variant.push_all(vs: List<&2, Variant>, n: U32) -> IO(U32):
  match vs:
    case []:
      IO.pure(U32, n)
    case VNil{} <> rest:
      do IO<U32>:
        gd.push_nil()
        Variant.push_all(rest, (n + 1 : U32))
    case VBool{v} <> rest:
      do IO<U32>:
        gd.push_bool(Variant.bit(v))
        Variant.push_all(rest, (n + 1 : U32))
    case VInt{v} <> rest:
      do IO<U32>:
        gd.push_int(v)
        Variant.push_all(rest, (n + 1 : U32))
    case VFloat{v} <> rest:
      do IO<U32>:
        gd.push_float(v)
        Variant.push_all(rest, (n + 1 : U32))
    case VStr{v} <> rest:
      do IO<U32>:
        gd.push_str(v)
        Variant.push_all(rest, (n + 1 : U32))
    case VVec2{x, y} <> rest:
      do IO<U32>:
        gd.push_vec2(x, y)
        Variant.push_all(rest, (n + 1 : U32))
    case VVec3{x, y, z} <> rest:
      do IO<U32>:
        gd.push_vec3(x, y, z)
        Variant.push_all(rest, (n + 1 : U32))
    case VColor{r, g, b, a} <> rest:
      do IO<U32>:
        gd.push_color(r, g, b, a)
        Variant.push_all(rest, (n + 1 : U32))
    case VArr{items} <> rest:
      do IO<U32>:
        k : U32 <- Variant.push_all(items, 0)
        gd.array_new(k)
        Variant.push_all(rest, (n + 1 : U32))
    case VObj{v} <> rest:
      do IO<U32>:
        Object.push(v)
        Variant.push_all(rest, (n + 1 : U32))
    case VOther{} <> rest:
      do IO<U32>:
        gd.push_nil()
        Variant.push_all(rest, (n + 1 : U32))

# Pops the top as its kind. An array's items are popped by items, which is
# Variant.pop_n one level down, handed in because a def cannot name one below it.
def Variant.pop_as(
  kind: Nat, items: Nat -> IO(List<&2, Variant>)
) -> IO(Variant):
  match kind:
    case 0n:
      do IO<Variant>:
        gd.pop()
        return VNil{}
    case 1n:
      do IO<Variant>:
        v : Bool <- gd.pop_bool()
        return VBool{v}
    case 2n:
      do IO<Variant>:
        v : U32 <- gd.pop_int()
        return VInt{v}
    case 3n:
      do IO<Variant>:
        v : F32 <- gd.pop_float()
        return VFloat{v}
    case 4n:
      do IO<Variant>:
        v : String <- gd.pop_str()
        return VStr{v}
    case 5n:
      do IO<Variant>:
        p : F32 & F32 <- gd.pop_vec2()
        return Variant.vec2(p)
    case 6n:
      do IO<Variant>:
        v : Object <- Object.of(gd.pop_obj())
        return VObj{v}
    case 7n:
      do IO<Variant>:
        p : F32 & F32 & F32 <- gd.pop_vec3()
        return Variant.vec3(p)
    case 8n:
      do IO<Variant>:
        p : F32 & F32 & F32 & F32 <- gd.pop_color()
        return Variant.color(p)
    case 9n:
      do IO<Variant>:
        n : U32 <- gd.array_open()
        vs : List<&2, Variant> <- items(U32.to_nat(n))
        return VArr{vs}
    case other:
      do IO<Variant>:
        gd.pop()
        return VOther{}

# At the nesting limit an array pops as Other.
def Variant.flat(kind: Nat) -> Nat:
  match kind:
    case 9n:
      10n
    case other:
      other

# Pops n values pushed first to last: the top is the last, so each pop
# conses onto the ones after it. depth bounds how far arrays nest (deeper
# ones pop as Other), which is what lets the recursion pass the
# termination check, and keeps a program that imports this file provable.
def Variant.pop_n(+depth: Nat, n: Nat, acc: List<&2, Variant>) ->
  IO(List<&2, Variant>):
  match depth n:
    case depth 0n:
      IO.pure(List<&2, Variant>, acc)
    case 0n 1n+p:
      do IO<List<&2, Variant>>:
        kind : Nat <- gd.kind()
        v : Variant <- Variant.pop_as(Variant.flat(kind), k => IO.pure(List<&2, Variant>, []))
        Variant.pop_n(0n, p, v <> acc)
    case 1n+d 1n+p:
      do IO<List<&2, Variant>>:
        kind : Nat <- gd.kind()
        v : Variant <- Variant.pop_as(kind, k => Variant.pop_n(d, k, []))
        Variant.pop_n(1n+d, p, v <> acc)

def Variant.first(vs: List<&2, Variant>) -> Variant:
  match vs:
    case []:
      VNil{}
    case v <> rest:
      v

def Variant.pop() -> IO(Variant):
  do IO<Variant>:
    vs : List<&2, Variant> <- Variant.pop_n(32n, 1n, [])
    return Variant.first(vs)

# Signal
# ------

# A signal that fired: the tag its connect chose, and what it carried.
type Signal is Data:
  Signal{tag: U32, args: List<&2, Variant>}

def Signal.next() -> IO(Signal):
  do IO<Signal>:
    tag : U32 <- gd.event()
    argc : U32 <- gd.pop_int()
    args : List<&2, Variant> <- Variant.pop_n(32n, U32.to_nat(argc), [])
    return Signal{tag, args}

def Signal.take(n: Nat) -> IO(List<&2, Signal>):
  match n:
    case 0n:
      IO.pure(List<&2, Signal>, [])
    case 1n+p:
      do IO<List<&2, Signal>>:
        s : Signal <- Signal.next()
        rest : List<&2, Signal> <- Signal.take(p)
        return s <> rest

# API
# ---

# Prints through Godot: the text reaches the editor's Output panel.
def print(text: String) -> IO(Unit):
  gd.print(text)

# Waits for the next frame and answers the seconds since the last one. A
# program that never calls frame runs to its end inside _ready.
def frame() -> IO(F32):
  gd.frame()

# The BendRuntime node that hosts the program: the way into the scene.
def self() -> IO(Object):
  Object.of(gd.self())

# An engine singleton by name: "Input", "Engine", "Time", ..
def singleton(name: String) -> IO(Object):
  Object.of(gd.singleton(name))

# A new object of a class: "Sprite2D", "Label", .. A Node stays out of the
# scene until some add_child takes it.
def new(class: String) -> IO(Object):
  Object.of(gd.new(class))

# Calls a method by name, as GDScript's obj.call(method, ..args) does.
def call(obj: Object, method: String, args: List<&2, Variant>) -> IO(Variant):
  do IO<Variant>:
    n : U32 <- Variant.push_all(args, 0)
    Object.call(obj, method, n)
    Variant.pop()

def get(obj: Object, property: String) -> IO(Variant):
  call(obj, "get", [VStr{property}])

def set(obj: Object, property: String, value: Variant) -> IO(Unit):
  do IO<Unit>:
    gone : Variant <- call(obj, "set", [VStr{property}, value])
    return Unit{}

# A node by path, from another: Nil when the path leads nowhere.
def node(from: Object, path: String) -> IO(Variant):
  call(from, "get_node_or_null", [VStr{path}])

# Connects a signal of obj to the program under a tag of its choosing.
# Godot never calls into Bend: a signal that fires waits in a queue, and
# signals() hands the queue over.
def connect(obj: Object, signal: String, tag: U32) -> IO(Unit):
  Obj{slot} = obj
  gd.connect(slot, signal, tag)

# Every signal that fired since the last ask, oldest first. The natural
# place to ask is right after frame().
def signals() -> IO(List<&2, Signal>):
  do IO<List<&2, Signal>>:
    n : Nat <- gd.events()
    Signal.take(n)
