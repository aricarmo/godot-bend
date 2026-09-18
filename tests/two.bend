# Two Bend programs in one scene: each is a library of its own, with its
# own runtime and its own node class (this one BendRuntime, the other
# BendSecond, a child of this node). They meet through the engine: the
# other leaves a note on this node, and this one reads it.
import Base
import ../godot/Godot.bend as Godot
import ../godot/api/Object.bend as Object

def text(v: Godot.Variant) -> String:
  match v:
    case Godot.VStr{v}:
      v
    case other:
      "nothing"

def main() -> IO(Unit):
  do IO<Unit>:
    +me : Godot.Object <- Godot.self()
    dt : F32 <- Godot.frame()
    note : Godot.Variant <- Object.get_meta(me, "note")
    Godot.print("first: the note says " ++ text(note))
    Godot.print("bend: done")
