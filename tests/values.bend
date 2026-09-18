# Every kind a Variant carries goes to the engine and comes back the same:
# a Vector3 through a Node3D, a Color through a ColorRect, a nested array
# through a node's metadata, an array of objects from get_children. A
# negative Int is shown to be negative on the engine's side, by a method
# that answers text: one day before 1970.
import Base
import ../godot/Godot.bend as Godot

# One def shows a value and a list of them, since Bend has no mutual
# recursion: a value is shown as the list of itself.
def shows(vs: List<&2, Godot.Variant>) -> String:
  match vs:
    case []:
      ""
    case Godot.VNil{} <> rest:
      " nil" ++ shows(rest)
    case Godot.VBool{v} <> rest:
      " bool" ++ shows(rest)
    case Godot.VInt{v} <> rest:
      " " ++ U32.show(v) ++ shows(rest)
    case Godot.VFloat{v} <> rest:
      " " ++ F32.show(v) ++ shows(rest)
    case Godot.VStr{v} <> rest:
      " '" ++ v ++ "'" ++ shows(rest)
    case Godot.VVec2{x, y} <> rest:
      " v2(" ++ F32.show(x) ++ " " ++ F32.show(y) ++ ")" ++ shows(rest)
    case Godot.VVec3{x, y, z} <> rest:
      " v3(" ++ F32.show(x) ++ " " ++ F32.show(y) ++ " " ++ F32.show(z) ++ ")" ++ shows(rest)
    case Godot.VColor{r, g, b, a} <> rest:
      " rgba(" ++ F32.show(r) ++ " " ++ F32.show(g) ++ " " ++ F32.show(b) ++ " " ++ F32.show(a) ++ ")" ++ shows(rest)
    case Godot.VArr{items} <> rest:
      " [" ++ shows(items) ++ " ]" ++ shows(rest)
    case Godot.VObj{v} <> rest:
      " obj" ++ shows(rest)
    case other <> rest:
      " other" ++ shows(rest)

def show(v: Godot.Variant) -> String:
  shows([v])

def main() -> IO(Unit):
  do IO<Unit>:
    +me : Godot.Object <- Godot.self()
    +spot : Godot.Object <- Godot.new("Node3D")
    Godot.set(spot, "position", Godot.VVec3{1.5, 2.0, 3.25})
    at : Godot.Variant <- Godot.get(spot, "position")
    Godot.print("vector3: " ++ show(at))
    +rect : Godot.Object <- Godot.new("ColorRect")
    Godot.set(rect, "color", Godot.VColor{0.25, 0.5, 0.75, 1.0})
    ink : Godot.Variant <- Godot.get(rect, "color")
    Godot.print("color: " ++ show(ink))
    a : Godot.Variant <- Godot.call(me, "set_meta", [Godot.VStr{"bag"},
      Godot.VArr{[Godot.VInt{1}, Godot.VStr{"two"}, Godot.VArr{[Godot.VFloat{3.5}, Godot.VArr{[]}]}, Godot.VNil{}]}])
    bag : Godot.Variant <- Godot.call(me, "get_meta", [Godot.VStr{"bag"}])
    Godot.print("array: " ++ show(bag))
    b : Godot.Variant <- Godot.call(me, "add_child", [Godot.VObj{spot}])
    c : Godot.Variant <- Godot.call(me, "add_child", [Godot.VObj{rect}])
    kids : Godot.Variant <- Godot.call(me, "get_children", [])
    Godot.print("children: " ++ show(kids))
    time : Godot.Object <- Godot.singleton("Time")
    day : Godot.Variant <- Godot.call(time, "get_date_string_from_unix_time", [Godot.VInt{4294880896}])
    Godot.print("minus one day: " ++ show(day))
    d : Godot.Variant <- Godot.call(me, "set_meta", [Godot.VStr{"n"}, Godot.VInt{4294967295}])
    n : Godot.Variant <- Godot.call(me, "get_meta", [Godot.VStr{"n"}])
    Godot.print("minus one: " ++ show(n))
    Godot.print("bend: done")
