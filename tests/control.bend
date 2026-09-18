# Godot.new answers an object ready for use. A Control is the hard case:
# one built without its post-initialize notification crashes the engine
# on its first property.
import Base
import ../godot/Godot.bend as Godot

def show(v: Godot.Variant) -> String:
  match v:
    case Godot.VVec2{x, y}:
      F32.show(x) ++ " x " ++ F32.show(y)
    case other:
      "?"

def main() -> IO(Unit):
  do IO<Unit>:
    me : Godot.Object <- Godot.self()
    +r : Godot.Object <- Godot.new("ColorRect")
    Godot.set(r, "size", Godot.VVec2{16.0, 96.0})
    added : Godot.Variant <- Godot.call(me, "add_child", [Godot.VObj{r}])
    size : Godot.Variant <- Godot.get(r, "size")
    Godot.print("size " ++ show(size))
    Godot.print("bend: done")
