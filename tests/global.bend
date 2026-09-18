# What belongs to no class: utility functions of each answer type, a
# global enum value, and a static method (Image.create_empty) whose answer
# is an object the typed API then reads.
import Base
import ../godot/Godot.bend as Godot
import ../godot/api/Global.bend as Global
import ../godot/api/Image.bend as Image

def float(v: Godot.Variant) -> String:
  match v:
    case Godot.VFloat{v}:
      F32.show(v)
    case other:
      "?"

def main() -> IO(Unit):
  do IO<Unit>:
    a : F32 <- Global.lerpf(0.0, 10.0, 0.25)
    Godot.print("lerpf: " ++ F32.show(a))
    b : U32 <- Global.randi_range(3, 3)
    Godot.print("randi_range: " ++ U32.show(b))
    c : U32 <- Global.absi(4294967291)
    Godot.print("absi of minus five: " ++ U32.show(c))
    d : U32 <- Global.signi(4294967291)
    Godot.print("signi of minus five: " ++ U32.show(d))
    e : Bool <- Global.is_equal_approx(1.0, 1.0000001)
    Godot.print("is_equal_approx: " ++ Bool.show(e))
    f : String <- Global.type_string(Global.TYPE_VECTOR2())
    Godot.print("type_string: " ++ f)
    g : Godot.Variant <- Global.lerp(Godot.VFloat{0.0}, Godot.VFloat{4.0}, Godot.VFloat{0.5})
    Godot.print("lerp of variants: " ++ float(g))
    Godot.print("KEY_W: " ++ U32.show(Global.KEY_W()))
    +image : Godot.Object <- Image.create_empty(8, 4, False{}, Image.FORMAT_RGBA8())
    w : U32 <- Image.get_width(image)
    h : U32 <- Image.get_height(image)
    Godot.print("image: " ++ U32.show(w) ++ " x " ++ U32.show(h))
    Godot.print("bend: done")
