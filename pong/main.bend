# Pong, in Bend, inside Godot. The rules are pure functions over F32s; the
# IO loop at the bottom reads the keyboard, steps the rules once per frame
# and moves four Godot nodes. W/S or the arrows move the left paddle; the
# right one follows the ball.
import Base
import ../godot/Godot.bend as Godot
import ../godot/api/Node.bend as Node
import ../godot/api/Control.bend as Control
import ../godot/api/ColorRect.bend as ColorRect
import ../godot/api/Label.bend as Label
import ../godot/api/Input.bend as Input
import ../godot/api/RenderingServer.bend as RenderingServer

# Rules
# =====

# The field is 1152 x 648; a paddle is 16 x 96, the ball 16 x 16. Every
# position is a top left corner.

type Ball is Data:
  Ball{x: F32, y: F32, vx: F32, vy: F32}

def pick(c: Bool, a: F32, b: F32) -> F32:
  match c:
    case True{}:
      a
    case False{}:
      b

def axis(up: Bool, down: Bool) -> F32:
  match up down:
    case True{} False{}:
      F32.neg(1.0)
    case False{} True{}:
      1.0
    case _ _:
      0.0

def paddle(y: F32, dir: F32, dt: F32) -> F32:
  F32.clamp((y + dir * 460.0 * dt : F32), 0.0, 552.0)

# The machine's paddle chases the ball's center, slower than the ball can
# fly, so a steep shot beats it.
def chase(+y: F32, by: F32, +dt: F32) -> F32:
  F32.clamp((y + F32.clamp((by - 40.0 - y : F32), F32.neg((330.0 * dt : F32)), (330.0 * dt : F32)) : F32), 0.0, 552.0)

def wall(+y: F32, +vy: F32) -> F32:
  pick((y < 0.0 : F32), F32.abs(vy),
    pick((y > 632.0 : F32), F32.neg(F32.abs(vy)), vy))

# The ball at (bx, by) overlaps the paddle at (px, py).
def hits(+bx: F32, +by: F32, +px: F32, +py: F32) -> Bool:
  ((bx < px + 16.0) && (bx + 16.0 > px) && (by + 16.0 > py) && (by < py + 96.0) : F32)

# A paddle sends the ball back 6% faster, and steers it by where it hit.
def turn(
  left: Bool, right: Bool, +x: F32, +y: F32, +vx: F32, +vy: F32, ly: F32,
  ry: F32
) -> Ball:
  match left right:
    case True{} _:
      Ball{x, y, (F32.abs(vx) * 1.06 : F32), (vy + (y - 40.0 - ly) * 5.0 : F32)}
    case False{} True{}:
      Ball{x, y, F32.neg((F32.abs(vx) * 1.06 : F32)), (vy + (y - 40.0 - ry) * 5.0 : F32)}
    case False{} False{}:
      Ball{x, y, vx, vy}

def fly(+x: F32, +y: F32, +vx: F32, +vy: F32, +ly: F32, +ry: F32) -> Ball:
  turn(Bool.and((vx < 0.0 : F32), hits(x, y, 32.0, ly)),
    Bool.and((vx > 0.0 : F32), hits(x, y, 1104.0, ry)),
    x, y, vx, wall(y, vy), ly, ry)

def Ball.step(b: Ball, +dt: F32, ly: F32, ry: F32) -> Ball:
  Ball{x, y, +vx, +vy} = b
  fly((x + vx * dt : F32), (y + vy * dt : F32), vx, vy, ly, ry)

def Ball.serve(toward: F32) -> Ball:
  Ball{568.0, 316.0, (toward * 380.0 : F32), 140.0}

def Ball.x(b: Ball) -> F32:
  Ball{x, y, vx, vy} = b
  x

def Ball.y(b: Ball) -> F32:
  Ball{x, y, vx, vy} = b
  y

# Scene
# =====

type Scene is Data:
  Scene{input: Godot.Object, left: Godot.Object, right: Godot.Object,
    ball: Godot.Object, score: Godot.Object}

def rect(
  +me: Godot.Object, at: Godot.Vec2, size: Godot.Vec2, ink: Godot.Color
) -> IO(Godot.Object):
  do IO<Godot.Object>:
    +r : Godot.Object <- ColorRect.new()
    ColorRect.set_color(r, ink)
    Control.set_size(r, size)
    Control.set_position(r, at)
    Node.add_child(me, r)
    return r

def label(+me: Godot.Object) -> IO(Godot.Object):
  do IO<Godot.Object>:
    +l : Godot.Object <- Label.new()
    Control.set_position(l, Godot.Vec2{516.0, 24.0})
    Control.add_theme_font_size_override(l, "font_size", 56)
    Node.add_child(me, l)
    return l

# Either of two keys, by Godot's keycodes.
def key(+input: Godot.Object, a: U32, b: U32) -> IO(Bool):
  do IO<Bool>:
    x : Bool <- Input.is_key_pressed(input, a)
    y : Bool <- Input.is_key_pressed(input, b)
    return Bool.or(x, y)

def place(node: Godot.Object, x: F32, y: F32) -> IO(Unit):
  Control.set_position(node, Godot.Vec2{x, y})

def draw(sc: Scene, ly: F32, ry: F32, b: Ball) -> IO(Unit):
  Scene{input, left, right, ball, score} = sc
  Ball{x, y, vx, vy} = b
  do IO<Unit>:
    place(left, 32.0, ly)
    place(right, 1104.0, ry)
    place(ball, x, y)

def tally(sc: Scene, +ls: U32, +rs: U32) -> IO(Unit):
  Scene{input, left, right, ball, score} = sc
  do IO<Unit>:
    Label.set_text(score, U32.show(ls) ++ "   " ++ U32.show(rs))
    Godot.print("score " ++ U32.show(ls) ++ " x " ++ U32.show(rs))

def Scene.input(sc: Scene) -> Godot.Object:
  Scene{input, left, right, ball, score} = sc
  input

# Loop
# ====

# The frame's end: a ball past an edge is a point and a new serve, toward
# whoever scored it. rest is the loop (a def cannot name one defined below
# it).
def point(
  past_left: Bool, past_right: Bool, +sc: Scene, ly: F32, ry: F32, b: Ball,
  +ls: U32, +rs: U32,
  rest: Scene -> F32 -> F32 -> Ball -> U32 -> U32 -> IO(Unit)
) -> IO(Unit):
  match past_left past_right:
    case True{} _:
      do IO<Unit>:
        tally(sc, ls, (rs + 1 : U32))
        rest(sc, ly, ry, Ball.serve(1.0), ls, (rs + 1 : U32))
    case False{} True{}:
      do IO<Unit>:
        tally(sc, (ls + 1 : U32), rs)
        rest(sc, ly, ry, Ball.serve(F32.neg(1.0)), (ls + 1 : U32), rs)
    case False{} False{}:
      rest(sc, ly, ry, b, ls, rs)

def play(
  +sc: Scene, +ly: F32, +ry: F32, +b: Ball, ls: U32, rs: U32,
  rest: Scene -> F32 -> F32 -> Ball -> U32 -> U32 -> IO(Unit)
) -> IO(Unit):
  do IO<Unit>:
    draw(sc, ly, ry, b)
    point((Ball.x(b) < F32.neg(16.0) : F32), (Ball.x(b) > 1152.0 : F32), sc,
      ly, ry, b, ls, rs, rest)

@unsafe
def loop(+sc: Scene, +ly: F32, +ry: F32, +b: Ball, ls: U32, rs: U32) -> IO(Unit):
  do IO<Unit>:
    raw : F32 <- Godot.frame()
    +dt : F32 = F32.min(raw, 0.05)
    up : Bool <- key(Scene.input(sc), 87, 4194320)
    down : Bool <- key(Scene.input(sc), 83, 4194322)
    play(sc, paddle(ly, axis(up, down), dt), chase(ry, Ball.y(b), dt),
      Ball.step(b, dt, ly, ry), ls, rs,
      s => l => r => n => p => q => loop(s, l, r, n, p, q))

def main() -> IO(Unit):
  do IO<Unit>:
    +me : Godot.Object <- Godot.self()
    input : Godot.Object <- Input.singleton()
    server : Godot.Object <- RenderingServer.singleton()
    RenderingServer.set_default_clear_color(server, Godot.Rgba{0.07, 0.08, 0.11, 1.0})
    left : Godot.Object <- rect(me, Godot.Vec2{32.0, 276.0}, Godot.Vec2{16.0, 96.0}, Godot.Rgba{0.49, 0.88, 0.63, 1.0})
    right : Godot.Object <- rect(me, Godot.Vec2{1104.0, 276.0}, Godot.Vec2{16.0, 96.0}, Godot.Rgba{0.96, 0.55, 0.45, 1.0})
    ball : Godot.Object <- rect(me, Godot.Vec2{568.0, 316.0}, Godot.Vec2{16.0, 16.0}, Godot.Rgba{0.95, 0.95, 0.9, 1.0})
    score : Godot.Object <- label(me)
    +sc : Scene = Scene{input, left, right, ball, score}
    tally(sc, 0, 0)
    loop(sc, 276.0, 276.0, Ball.serve(1.0), 0, 0)
