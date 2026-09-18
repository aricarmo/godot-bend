# The mistakes a program can make reach Godot's error log and answer Nil;
# none takes the engine down. Expected output, in order: kind lines for a
# missing method, a freed object, and a value of every carried kind.
import Base
import ../godot/Godot.bend as Godot

def kind(v: Godot.Variant) -> String:
  match v:
    case Godot.VNil{}:
      "nil"
    case Godot.VBool{v}:
      "bool"
    case Godot.VInt{v}:
      "int " ++ U32.show(v)
    case Godot.VFloat{v}:
      "float " ++ F32.show(v)
    case Godot.VStr{v}:
      "str " ++ v
    case Godot.VVec2{x, y}:
      "vec2"
    case Godot.VObj{v}:
      "obj"
    case other:
      "other"

def say(label: String, v: Godot.Variant) -> IO(Unit):
  Godot.print(label ++ ": " ++ kind(v))

def main() -> IO(Unit):
  do IO<Unit>:
    +me : Godot.Object <- Godot.self()
    a : Godot.Variant <- Godot.call(me, "no_such_method", [])
    say("missing method", a)
    +node : Godot.Object <- Godot.new("Node2D")
    b : Godot.Variant <- Godot.call(node, "free", [])
    c : Godot.Variant <- Godot.call(node, "get_name", [])
    say("freed object", c)
    d : Godot.Variant <- Godot.call(me, "get_child_count", [])
    say("int", d)
    e : Godot.Variant <- Godot.call(me, "is_inside_tree", [])
    say("bool", e)
    f : Godot.Variant <- Godot.get(me, "name")
    say("string name", f)
    g : Godot.Variant <- Godot.call(me, "get_parent", [])
    say("object", g)
    h : Godot.Variant <- Godot.call(me, "get_children", [])
    say("array", h)
    i : Godot.Variant <- Godot.node(me, "nowhere")
    say("null object", i)
    none : Godot.Object <- Godot.singleton("NoSuchSingleton")
    Godot.print("bend: done")
