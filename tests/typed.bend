# The generated class files (godot/api): a constructor, typed arguments
# and answers, an enum value, a method's .all form with its defaulted
# arguments, an answer that is an object, one that is a list, and a vararg.
import Base
import ../godot/Godot.bend as Godot
import ../godot/api/Object.bend as Object
import ../godot/api/Node.bend as Node
import ../godot/api/Node2D.bend as Node2D

def count(vs: List<&2, Godot.Variant>, n: U32) -> U32:
  match vs:
    case []:
      n
    case v <> rest:
      count(rest, (n + 1 : U32))

def point(p: Godot.Vec2) -> String:
  Godot.Vec2{x, y} = p
  F32.show(x) ++ " " ++ F32.show(y)

def heard(ss: List<&2, Godot.Signal>) -> String:
  match ss:
    case []:
      "nothing"
    case Godot.Signal{tag, args} <> rest:
      "tag " ++ U32.show(tag) ++ " with " ++ U32.show(count(args, 0)) ++ " values"

def main() -> IO(Unit):
  do IO<Unit>:
    +me : Godot.Object <- Godot.self()
    +hero : Godot.Object <- Node2D.new()
    Node.set_name(hero, "Hero")
    Node.add_child.all(me, hero, False{}, Node.INTERNAL_MODE_DISABLED())
    name : String <- Node.get_name(hero)
    Godot.print("name: " ++ name)
    Node2D.set_position(hero, Godot.Vec2{12.5, 40.0})
    at : Godot.Vec2 <- Node2D.get_position(hero)
    Godot.print("position: " ++ point(at))
    Node.set_process_mode(hero, Node.PROCESS_MODE_ALWAYS())
    mode : U32 <- Node.get_process_mode(hero)
    Godot.print("process mode: " ++ U32.show(mode))
    +parent : Godot.Object <- Node.get_parent(hero)
    whose : String <- Node.get_name(parent)
    Godot.print("parent: " ++ whose)
    kids : List<&2, Godot.Variant> <- Node.get_children(me)
    Godot.print("children: " ++ U32.show(count(kids, 0)))
    inside : Bool <- Node.is_ancestor_of(me, hero)
    Godot.print("ancestor: " ++ Bool.show(inside))
    Object.add_user_signal(me, "hit")
    Godot.connect(me, "hit", 5)
    code : U32 <- Object.emit_signal(me, "hit", [Godot.VInt{1}, Godot.VStr{"two"}])
    ss : List<&2, Godot.Signal> <- Godot.signals()
    Godot.print("heard: " ++ heard(ss))
    Godot.print("bend: done")
