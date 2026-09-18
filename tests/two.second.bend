# The second program of tests/two.bend: a child node, so it is ready
# first, and it leaves a note on its parent, the first program's node.
import Base
import ../godot/Godot.bend as Godot
import ../godot/api/Object.bend as Object
import ../godot/api/Node.bend as Node

def main() -> IO(Unit):
  do IO<Unit>:
    me : Godot.Object <- Godot.self()
    parent : Godot.Object <- Node.get_parent(me)
    Object.set_meta(parent, "note", Godot.VStr{"hello from the second program"})
    Godot.print("second: left a note")
