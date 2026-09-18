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
# instance ids (and the row's generation), never a pointer: a handle is
# plain Data, so it copies freely, and one whose object was freed, or that
# was dropped, answers Nil to every call instead of dangling. Slot 0 is
# null. The raw effects carry the bare U32.
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

# Godot's numeric structs (Rect2, Transform2D, Basis, ..) are flat runs of
# numbers: pack folds the top n into a value of a Variant type, unpack
# spreads one out, pushes how many, and answers the type.
def gd.pack(kind: U32, n: U32) -> IO(Unit):
  import "./godot.c"
  import "./godot.js"

def gd.unpack() -> IO(U32):
  import "./godot.c"
  import "./godot.js"

def gd.push_rid(hi: U32, lo: U32) -> IO(Unit):
  import "./godot.c"
  import "./godot.js"

def gd.pop_rid() -> IO(U32 & U32):
  import "./godot.c"
  import "./godot.js"

# A Callable that queues a signal under the tag.
def gd.push_callable(tag: U32) -> IO(Unit):
  import "./godot.c"
  import "./godot.js"

# Folds the top n values into a packed array of a Variant type.
def gd.packed_new(kind: U32, n: U32) -> IO(Unit):
  import "./godot.c"
  import "./godot.js"

# A Dictionary from the top n values, key then value; and back, answering n.
def gd.dict_new(n: U32) -> IO(Unit):
  import "./godot.c"
  import "./godot.js"

def gd.dict_open() -> IO(U32):
  import "./godot.c"
  import "./godot.js"

def gd.push_obj(slot: U32) -> IO(Unit):
  import "./godot.c"
  import "./godot.js"

def gd.call(slot: U32, method: String, argc: U32) -> IO(Unit):
  import "./godot.c"
  import "./godot.js"

# The top's kind: 0 Nil, 1 Bool, 2 Int, 3 Float, 4 String, 5 Vector2,
# 6 Object, 7 Vector3, 8 Color, 9 Array (or a packed array), 10 anything
# else, 11 a struct of floats, 12 a struct of ints, 13 RID, 14 Dictionary.
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

# A class's static method, by the hash extension_api.json gives it: pops
# argc arguments and pushes the result.
def gd.static(class: String, method: String, hash: U32, argc: U32) -> IO(Unit):
  import "./godot.c"
  import "./godot.js"

# A utility function, by its hash. sig spells its types, which the C side
# needs: a letter per argument, '>', and the answer's.
def gd.util(name: String, hash: U32, sig: String) -> IO(Unit):
  import "./godot.c"
  import "./godot.js"

def gd.drop(slot: U32) -> IO(Unit):
  import "./godot.c"
  import "./godot.js"

def gd.listen(on: U32) -> IO(Unit):
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
#
# VFloats and VInts are Godot's numeric structs, by Variant type and their
# numbers in memory order (the Typed section below gives the common ones
# names). A VDict lists key, value, key, value. Two kinds only go in: a
# VPacked is a packed array of a Variant type (one comes back as a VArr),
# and a VCall is a Callable that queues a signal under its tag, so a
# callback handed to the engine arrives in signals().
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
  VFloats{kind: U32, nums: List<&2, F32>}
  VInts{kind: U32, nums: List<&2, U32>}
  VRid{hi: U32, lo: U32}
  VDict{flat: List<&2, Variant>}
  VPacked{kind: U32, items: List<&2, Variant>}
  VCall{tag: U32}

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

def Variant.push_floats(ns: List<&2, F32>, n: U32) -> IO(U32):
  match ns:
    case []:
      IO.pure(U32, n)
    case x <> rest:
      do IO<U32>:
        gd.push_float(x)
        Variant.push_floats(rest, (n + 1 : U32))

def Variant.push_ints(ns: List<&2, U32>, n: U32) -> IO(U32):
  match ns:
    case []:
      IO.pure(U32, n)
    case x <> rest:
      do IO<U32>:
        gd.push_int(x)
        Variant.push_ints(rest, (n + 1 : U32))

def Variant.pop_floats(n: Nat, acc: List<&2, F32>) -> IO(List<&2, F32>):
  match n:
    case 0n:
      IO.pure(List<&2, F32>, acc)
    case 1n+p:
      do IO<List<&2, F32>>:
        x : F32 <- gd.pop_float()
        Variant.pop_floats(p, x <> acc)

def Variant.pop_ints(n: Nat, acc: List<&2, U32>) -> IO(List<&2, U32>):
  match n:
    case 0n:
      IO.pure(List<&2, U32>, acc)
    case 1n+p:
      do IO<List<&2, U32>>:
        x : U32 <- gd.pop_int()
        Variant.pop_ints(p, x <> acc)

def Variant.rid(p: U32 & U32) -> Variant:
  (hi, lo) = p
  VRid{hi, lo}

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
    case VFloats{kind, nums} <> rest:
      do IO<U32>:
        k : U32 <- Variant.push_floats(nums, 0)
        gd.pack(kind, k)
        Variant.push_all(rest, (n + 1 : U32))
    case VInts{kind, nums} <> rest:
      do IO<U32>:
        k : U32 <- Variant.push_ints(nums, 0)
        gd.pack(kind, k)
        Variant.push_all(rest, (n + 1 : U32))
    case VRid{hi, lo} <> rest:
      do IO<U32>:
        gd.push_rid(hi, lo)
        Variant.push_all(rest, (n + 1 : U32))
    case VDict{flat} <> rest:
      do IO<U32>:
        k : U32 <- Variant.push_all(flat, 0)
        gd.dict_new(k)
        Variant.push_all(rest, (n + 1 : U32))
    case VPacked{kind, items} <> rest:
      do IO<U32>:
        k : U32 <- Variant.push_all(items, 0)
        gd.packed_new(kind, k)
        Variant.push_all(rest, (n + 1 : U32))
    case VCall{tag} <> rest:
      do IO<U32>:
        gd.push_callable(tag)
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
    case 11n:
      do IO<Variant>:
        kind : U32 <- gd.unpack()
        n : U32 <- gd.pop_int()
        nums : List<&2, F32> <- Variant.pop_floats(U32.to_nat(n), [])
        return VFloats{kind, nums}
    case 12n:
      do IO<Variant>:
        kind : U32 <- gd.unpack()
        n : U32 <- gd.pop_int()
        nums : List<&2, U32> <- Variant.pop_ints(U32.to_nat(n), [])
        return VInts{kind, nums}
    case 13n:
      do IO<Variant>:
        p : U32 & U32 <- gd.pop_rid()
        return Variant.rid(p)
    case 14n:
      do IO<Variant>:
        n : U32 <- gd.dict_open()
        vs : List<&2, Variant> <- items(U32.to_nat(n))
        return VDict{vs}
    case other:
      do IO<Variant>:
        gd.pop()
        return VOther{}

# At the nesting limit an array or a dictionary pops as Other.
def Variant.flat(kind: Nat) -> Nat:
  match kind:
    case 9n:
      10n
    case 14n:
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

# Lets go of a handle. The table keeps every object a program meets (and
# keeps a RefCounted one alive) until then, so a program that meets new
# objects without end drops the ones it is done with. It frees no node:
# call "queue_free" for that. The handle, and every copy, then names
# nothing.
def drop(obj: Object) -> IO(Unit):
  Obj{slot} = obj
  gd.drop(slot)

# Input events join the signal queue, already taken apart into values,
# under these tags: a key carries [VInt keycode, VBool pressed, VBool
# echo], a mouse button [VInt index, VBool pressed, VVec2 position], a
# mouse move [VVec2 position, VVec2 relative]. They are off until listen.
def listen(on: Bool) -> IO(Unit):
  gd.listen(Variant.bit(on))

def key_tag() -> U32:
  4294967295

def button_tag() -> U32:
  4294967294

def motion_tag() -> U32:
  4294967293

# Typed
# -----

# What the generated class files (godot/api) are written in: Bend types
# for the engine's small values, a reading of a Variant as each type (the
# type's zero when the Variant is of another kind), and a call per answer
# type.
type Vec2 is Data:
  Vec2{x: F32, y: F32}

type Vec3 is Data:
  Vec3{x: F32, y: F32, z: F32}

type Color is Data:
  Rgba{r: F32, g: F32, b: F32, a: F32}

def null() -> Object:
  Obj{0}

def vec2(p: Vec2) -> Variant:
  Vec2{x, y} = p
  VVec2{x, y}

def vec3(p: Vec3) -> Variant:
  Vec3{x, y, z} = p
  VVec3{x, y, z}

def color(c: Color) -> Variant:
  Rgba{r, g, b, a} = c
  VColor{r, g, b, a}

def to_bool(v: Variant) -> Bool:
  match v:
    case VBool{v}:
      v
    case other:
      False{}

def to_int(v: Variant) -> U32:
  match v:
    case VInt{v}:
      v
    case VFloat{v}:
      F32.to_u32(v)
    case other:
      0

def to_float(v: Variant) -> F32:
  match v:
    case VFloat{v}:
      v
    case VInt{v}:
      F32.from_nat(U32.to_nat(v))
    case other:
      0.0

def to_str(v: Variant) -> String:
  match v:
    case VStr{v}:
      v
    case other:
      ""

def to_vec2(v: Variant) -> Vec2:
  match v:
    case VVec2{x, y}:
      Vec2{x, y}
    case other:
      Vec2{0.0, 0.0}

def to_vec3(v: Variant) -> Vec3:
  match v:
    case VVec3{x, y, z}:
      Vec3{x, y, z}
    case other:
      Vec3{0.0, 0.0, 0.0}

def to_color(v: Variant) -> Color:
  match v:
    case VColor{r, g, b, a}:
      Rgba{r, g, b, a}
    case other:
      Rgba{0.0, 0.0, 0.0, 1.0}

def to_obj(v: Variant) -> Object:
  match v:
    case VObj{v}:
      v
    case other:
      Obj{0}

def to_list(v: Variant) -> List<&2, Variant>:
  match v:
    case VArr{items}:
      items
    case other:
      []

def run(obj: Object, method: String, args: List<&2, Variant>) -> IO(Unit):
  do IO<Unit>:
    gone : Variant <- call(obj, method, args)
    return Unit{}

def call_bool(obj: Object, method: String, args: List<&2, Variant>) -> IO(Bool):
  do IO<Bool>:
    v : Variant <- call(obj, method, args)
    return to_bool(v)

def call_int(obj: Object, method: String, args: List<&2, Variant>) -> IO(U32):
  do IO<U32>:
    v : Variant <- call(obj, method, args)
    return to_int(v)

def call_float(obj: Object, method: String, args: List<&2, Variant>) -> IO(F32):
  do IO<F32>:
    v : Variant <- call(obj, method, args)
    return to_float(v)

def call_str(obj: Object, method: String, args: List<&2, Variant>) -> IO(String):
  do IO<String>:
    v : Variant <- call(obj, method, args)
    return to_str(v)

def call_vec2(obj: Object, method: String, args: List<&2, Variant>) -> IO(Vec2):
  do IO<Vec2>:
    v : Variant <- call(obj, method, args)
    return to_vec2(v)

def call_vec3(obj: Object, method: String, args: List<&2, Variant>) -> IO(Vec3):
  do IO<Vec3>:
    v : Variant <- call(obj, method, args)
    return to_vec3(v)

def call_color(obj: Object, method: String, args: List<&2, Variant>) -> IO(Color):
  do IO<Color>:
    v : Variant <- call(obj, method, args)
    return to_color(v)

def call_obj(obj: Object, method: String, args: List<&2, Variant>) -> IO(Object):
  do IO<Object>:
    v : Variant <- call(obj, method, args)
    return to_obj(v)

def call_list(obj: Object, method: String, args: List<&2, Variant>) ->
  IO(List<&2, Variant>):
  do IO<List<&2, Variant>>:
    v : Variant <- call(obj, method, args)
    return to_list(v)

# A static method of a class, and a utility function (randf, lerp, ..).
# The generated files call these; the hash and sig come from
# extension_api.json.
def static(
  class: String, method: String, hash: U32, args: List<&2, Variant>
) -> IO(Variant):
  do IO<Variant>:
    n : U32 <- Variant.push_all(args, 0)
    gd.static(class, method, hash, n)
    Variant.pop()

def util(
  name: String, hash: U32, sig: String, args: List<&2, Variant>
) -> IO(Variant):
  do IO<Variant>:
    n : U32 <- Variant.push_all(args, 0)
    gd.util(name, hash, sig)
    Variant.pop()

# Drops an answer nobody reads.
def done(m: IO(Variant)) -> IO(Unit):
  do IO<Unit>:
    gone : Variant <- m
    return Unit{}

# Structs
# -------

# Names for the numeric structs a program meets most, over VFloats and
# VInts. The others (Vector4, Plane, AABB, Projection, Vector4i) go as the
# raw Variant: VFloats{12, [x, y, z, w]} is a Vector4. A Basis is its three
# axes, as in GDScript; Godot lays it out by rows, so it is transposed on
# the way.
type Vec2i is Data:
  Vec2i{x: U32, y: U32}

type Vec3i is Data:
  Vec3i{x: U32, y: U32, z: U32}

type Rect2 is Data:
  Rect2{position: Vec2, size: Vec2}

type Rect2i is Data:
  Rect2i{position: Vec2i, size: Vec2i}

type Transform2D is Data:
  Transform2D{x: Vec2, y: Vec2, origin: Vec2}

type Quaternion is Data:
  Quaternion{x: F32, y: F32, z: F32, w: F32}

type Basis is Data:
  Basis{x: Vec3, y: Vec3, z: Vec3}

type Transform3D is Data:
  Transform3D{basis: Basis, origin: Vec3}

type Rid is Data:
  Rid{hi: U32, lo: U32}

def vec2i(p: Vec2i) -> Variant:
  Vec2i{x, y} = p
  VInts{6, [x, y]}

def vec3i(p: Vec3i) -> Variant:
  Vec3i{x, y, z} = p
  VInts{10, [x, y, z]}

def rect2(r: Rect2) -> Variant:
  Rect2{Vec2{a, b}, Vec2{c, d}} = r
  VFloats{7, [a, b, c, d]}

def rect2i(r: Rect2i) -> Variant:
  Rect2i{Vec2i{a, b}, Vec2i{c, d}} = r
  VInts{8, [a, b, c, d]}

def transform2d(t: Transform2D) -> Variant:
  Transform2D{Vec2{a, b}, Vec2{c, d}, Vec2{e, f}} = t
  VFloats{11, [a, b, c, d, e, f]}

def quaternion(q: Quaternion) -> Variant:
  Quaternion{x, y, z, w} = q
  VFloats{15, [x, y, z, w]}

def basis(m: Basis) -> Variant:
  Basis{Vec3{xx, xy, xz}, Vec3{yx, yy, yz}, Vec3{zx, zy, zz}} = m
  VFloats{17, [xx, yx, zx, xy, yy, zy, xz, yz, zz]}

def transform3d(t: Transform3D) -> Variant:
  Transform3D{Basis{Vec3{xx, xy, xz}, Vec3{yx, yy, yz}, Vec3{zx, zy, zz}}, Vec3{ox, oy, oz}} = t
  VFloats{18, [xx, yx, zx, xy, yy, zy, xz, yz, zz, ox, oy, oz]}

def rid(r: Rid) -> Variant:
  Rid{hi, lo} = r
  VRid{hi, lo}

def to_vec2i(v: Variant) -> Vec2i:
  match v:
    case VInts{kind, x <> y <> rest}:
      Vec2i{x, y}
    case other:
      Vec2i{0, 0}

def to_vec3i(v: Variant) -> Vec3i:
  match v:
    case VInts{kind, x <> y <> z <> rest}:
      Vec3i{x, y, z}
    case other:
      Vec3i{0, 0, 0}

def to_rect2(v: Variant) -> Rect2:
  match v:
    case VFloats{kind, a <> b <> c <> d <> rest}:
      Rect2{Vec2{a, b}, Vec2{c, d}}
    case other:
      Rect2{Vec2{0.0, 0.0}, Vec2{0.0, 0.0}}

def to_rect2i(v: Variant) -> Rect2i:
  match v:
    case VInts{kind, a <> b <> c <> d <> rest}:
      Rect2i{Vec2i{a, b}, Vec2i{c, d}}
    case other:
      Rect2i{Vec2i{0, 0}, Vec2i{0, 0}}

# The identity, when the Variant is no transform.
def to_transform2d(v: Variant) -> Transform2D:
  match v:
    case VFloats{kind, a <> b <> c <> d <> e <> f <> rest}:
      Transform2D{Vec2{a, b}, Vec2{c, d}, Vec2{e, f}}
    case other:
      Transform2D{Vec2{1.0, 0.0}, Vec2{0.0, 1.0}, Vec2{0.0, 0.0}}

def to_quaternion(v: Variant) -> Quaternion:
  match v:
    case VFloats{kind, x <> y <> z <> w <> rest}:
      Quaternion{x, y, z, w}
    case other:
      Quaternion{0.0, 0.0, 0.0, 1.0}

def to_basis(v: Variant) -> Basis:
  match v:
    case VFloats{kind, xx <> yx <> zx <> xy <> yy <> zy <> xz <> yz <> zz <> rest}:
      Basis{Vec3{xx, xy, xz}, Vec3{yx, yy, yz}, Vec3{zx, zy, zz}}
    case other:
      Basis{Vec3{1.0, 0.0, 0.0}, Vec3{0.0, 1.0, 0.0}, Vec3{0.0, 0.0, 1.0}}

def to_transform3d(v: Variant) -> Transform3D:
  match v:
    case VFloats{kind, xx <> yx <> zx <> xy <> yy <> zy <> xz <> yz <> zz <> ox <> oy <> oz <> rest}:
      Transform3D{Basis{Vec3{xx, xy, xz}, Vec3{yx, yy, yz}, Vec3{zx, zy, zz}}, Vec3{ox, oy, oz}}
    case other:
      Transform3D{Basis{Vec3{1.0, 0.0, 0.0}, Vec3{0.0, 1.0, 0.0}, Vec3{0.0, 0.0, 1.0}}, Vec3{0.0, 0.0, 0.0}}

def to_rid(v: Variant) -> Rid:
  match v:
    case VRid{hi, lo}:
      Rid{hi, lo}
    case other:
      Rid{0, 0}
