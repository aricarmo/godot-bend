# The kinds past the simple values. Each is checked by what the engine
# makes of it, not only by coming back: a Transform2D by the position and
# rotation the node then reports, a Transform3D by where it sends a point
# (which a transposed Basis would get wrong), a RID by the server taking
# it, a Callable by the tween calling it.
import Base
import ../godot/Godot.bend as Godot
import ../godot/api/Object.bend as Object
import ../godot/api/Node.bend as Node
import ../godot/api/Node2D.bend as Node2D
import ../godot/api/Node3D.bend as Node3D
import ../godot/api/CanvasItem.bend as CanvasItem
import ../godot/api/RenderingServer.bend as RenderingServer
import ../godot/api/Tween.bend as Tween

def floats(ns: List<&2, F32>) -> String:
  match ns:
    case []:
      ""
    case x <> rest:
      " " ++ F32.show(x) ++ floats(rest)

def ints(ns: List<&2, U32>) -> String:
  match ns:
    case []:
      ""
    case x <> rest:
      " " ++ U32.show(x) ++ ints(rest)

def shows(vs: List<&2, Godot.Variant>) -> String:
  match vs:
    case []:
      ""
    case Godot.VInt{v} <> rest:
      " " ++ U32.show(v) ++ shows(rest)
    case Godot.VStr{v} <> rest:
      " '" ++ v ++ "'" ++ shows(rest)
    case Godot.VArr{items} <> rest:
      " [" ++ shows(items) ++ " ]" ++ shows(rest)
    case Godot.VDict{flat} <> rest:
      " {" ++ shows(flat) ++ " }" ++ shows(rest)
    case Godot.VFloats{kind, nums} <> rest:
      " floats " ++ U32.show(kind) ++ ":" ++ floats(nums) ++ shows(rest)
    case Godot.VInts{kind, nums} <> rest:
      " ints " ++ U32.show(kind) ++ ":" ++ ints(nums) ++ shows(rest)
    case other <> rest:
      " ?" ++ shows(rest)

def vec2(p: Godot.Vec2) -> String:
  Godot.Vec2{x, y} = p
  F32.show(x) ++ " " ++ F32.show(y)

def vec3(p: Godot.Vec3) -> String:
  Godot.Vec3{x, y, z} = p
  F32.show(x) ++ " " ++ F32.show(y) ++ " " ++ F32.show(z)

def live(r: Godot.Rid) -> String:
  match r:
    case Godot.Rid{0, 0}:
      "null"
    case other:
      "set"

def meta(+me: Godot.Object, v: Godot.Variant) -> IO(String):
  do IO<String>:
    Object.set_meta(me, "m", v)
    back : Godot.Variant <- Object.get_meta(me, "m")
    return shows([back])

def tags(ss: List<&2, Godot.Signal>) -> String:
  match ss:
    case []:
      ""
    case Godot.Signal{tag, args} <> rest:
      " " ++ U32.show(tag) ++ tags(rest)

def tail(ss: List<&2, Godot.Signal>, rest: IO(Unit)) -> IO(Unit):
  match ss:
    case []:
      rest
    case s <> more:
      do IO<Unit>:
        Godot.print("the tween called:" ++ tags(s <> more))
        Godot.print("bend: done")

def wait(fuel: Nat) -> IO(Unit):
  match fuel:
    case 0n:
      Godot.print("the tween never called")
    case 1n+p:
      do IO<Unit>:
        dt : F32 <- Godot.frame()
        ss : List<&2, Godot.Signal> <- Godot.signals()
        tail(ss, wait(p))

def main() -> IO(Unit):
  do IO<Unit>:
    +me : Godot.Object <- Godot.self()
    +flat : Godot.Object <- Node2D.new()
    Node.add_child(me, flat)
    Node2D.set_transform(flat, Godot.Transform2D{Godot.Vec2{0.0, 1.0}, Godot.Vec2{F32.neg(1.0), 0.0}, Godot.Vec2{5.0, 7.0}})
    at : Godot.Vec2 <- Node2D.get_position(flat)
    turn : F32 <- Node2D.get_rotation(flat)
    Godot.print("transform2d: at " ++ vec2(at) ++ ", turned " ++ F32.show(turn))
    +solid : Godot.Object <- Node3D.new()
    Node.add_child(me, solid)
    Node3D.set_transform(solid, Godot.Transform3D{
      Godot.Basis{Godot.Vec3{0.0, 2.0, 0.0}, Godot.Vec3{F32.neg(1.0), 0.0, 0.0}, Godot.Vec3{0.0, 0.0, 1.0}},
      Godot.Vec3{1.0, 1.0, 1.0}})
    sent : Godot.Vec3 <- Node3D.to_global(solid, Godot.Vec3{1.0, 0.0, 0.0})
    Godot.print("transform3d: x axis sends (1 0 0) to " ++ vec3(sent))
    a : String <- meta(me, Godot.rect2i(Godot.Rect2i{Godot.Vec2i{1, 2}, Godot.Vec2i{30, 40}}))
    Godot.print("rect2i:" ++ a)
    b : String <- meta(me, Godot.quaternion(Godot.Quaternion{0.0, 0.5, 0.0, 1.0}))
    Godot.print("quaternion:" ++ b)
    c : String <- meta(me, Godot.VFloats{12, [1.0, 2.0, 3.0, 4.0]})
    Godot.print("vector4:" ++ c)
    d : String <- meta(me, Godot.VDict{[Godot.VStr{"a"}, Godot.VInt{1}, Godot.VStr{"b"}, Godot.VArr{[Godot.VInt{2}, Godot.VInt{3}]}]})
    Godot.print("dictionary:" ++ d)
    e : String <- meta(me, Godot.VPacked{34, [Godot.VStr{"x"}, Godot.VStr{"y"}]})
    Godot.print("packed strings:" ++ e)
    f : String <- meta(me, Godot.VPacked{29, [Godot.VInt{7}, Godot.VInt{255}]})
    Godot.print("packed bytes:" ++ f)
    +item : Godot.Rid <- CanvasItem.get_canvas_item(flat)
    Godot.print("rid: " ++ live(item))
    server : Godot.Object <- RenderingServer.singleton()
    RenderingServer.canvas_item_set_visible(server, item, False{})
    tween : Godot.Object <- Node.create_tween(me)
    step : Godot.Object <- Tween.tween_callback(tween, 77)
    wait(120n)
