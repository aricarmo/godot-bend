# A sprite driven from Bend: the program loads a texture, builds a
# Sprite2D, adds it to the scene and moves it in a circle, one step per
# frame. Once a second it reads the position back from the engine and
# prints it, and after five it ends.
import Base
import ../godot/Godot.bend as Godot
import ../godot/api/Node.bend as Node
import ../godot/api/Node2D.bend as Node2D
import ../godot/api/Sprite2D.bend as Sprite2D
import ../godot/api/ResourceLoader.bend as ResourceLoader

def show(p: Godot.Vec2) -> String:
  Godot.Vec2{x, y} = p
  "(" ++ F32.show(x) ++ ", " ++ F32.show(y) ++ ")"

def report(sprite: Godot.Object) -> IO(Unit):
  do IO<Unit>:
    at : Godot.Vec2 <- Node2D.get_position(sprite)
    Godot.print("sprite at " ++ show(at))

# A frame's end: more says the second is still running, last that it is
# the fifth, and rest is the loop (a def cannot name one defined below it).
def step(
  more: Bool, last: Bool, +sprite: Godot.Object, +time: F32, tick: F32,
  secs: U32, rest: Godot.Object -> F32 -> F32 -> U32 -> IO(Unit)
) -> IO(Unit):
  match more last:
    case True{} _:
      rest(sprite, time, tick, secs)
    case False{} False{}:
      do IO<Unit>:
        report(sprite)
        rest(sprite, time, 0.0, (secs + 1 : U32))
    case False{} True{}:
      do IO<Unit>:
        report(sprite)
        Godot.print("bend: done")

# Moves the sprite to its place at time, then ends the frame. The + makes
# a parameter reusable; a plain one is affine and may be read once.
def move(
  +sprite: Godot.Object, +time: F32, +tick: F32, +secs: U32,
  rest: Godot.Object -> F32 -> F32 -> U32 -> IO(Unit)
) -> IO(Unit):
  do IO<Unit>:
    Node2D.set_position(sprite, Godot.Vec2{
      (576.0 + 220.0 * F32.cos(time) : F32),
      (324.0 + 220.0 * F32.sin(time) : F32)})
    Node2D.set_rotation(sprite, time)
    step(F32.is_lt(tick, 1.0), U32.is_eq(secs, 4), sprite, time, tick, secs,
      rest)

@unsafe
def loop(+sprite: Godot.Object, time: F32, tick: F32, secs: U32) -> IO(Unit):
  do IO<Unit>:
    +dt : F32 <- Godot.frame()
    move(sprite, (time + dt : F32), (tick + dt : F32), secs,
      s => t => k => n => loop(s, t, k, n))

def main() -> IO(Unit):
  do IO<Unit>:
    Godot.print("hello from Bend, inside Godot")
    +me : Godot.Object <- Godot.self()
    loader : Godot.Object <- ResourceLoader.singleton()
    texture : Godot.Object <- ResourceLoader.load(loader, "res://icon.svg")
    +sprite : Godot.Object <- Sprite2D.new()
    Sprite2D.set_texture(sprite, texture)
    Node.add_child(me, sprite)
    loop(sprite, 0.0, 0.0, 0)
