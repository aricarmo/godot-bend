# The first Bend program to run inside Godot: it greets through Godot's
# print, then counts frames, reporting once a second, and ends after five.
import Base
import ../godot/Godot.bend as Godot

def report(frames: U32) -> IO(Unit):
  Godot.print(U32.show(frames) ++ " frames in the last second")

# One frame: frames and micros count since the last report; more says the
# second is still running, last that it is the fifth, and rest is the loop
# (a def cannot name one defined below it).
def step(
  more: Bool, last: Bool, frames: U32, micros: U32, secs: U32,
  rest: U32 -> U32 -> U32 -> IO(Unit)
) -> IO(Unit):
  match more last:
    case True{} _:
      rest(frames, micros, secs)
    case False{} False{}:
      do IO<Unit>:
        report(frames)
        rest(0, 0, (secs + 1 : U32))
    case False{} True{}:
      do IO<Unit>:
        report(frames)
        Godot.print("bend: done")

# Splits the frame's totals into step's two questions. The + makes a
# parameter reusable; a plain one is affine and may be read once.
def tick(
  +frames: U32, +micros: U32, +secs: U32,
  rest: U32 -> U32 -> U32 -> IO(Unit)
) -> IO(Unit):
  step(U32.is_lt(micros, 1000000), U32.is_eq(secs, 4), frames, micros, secs,
    rest)

@unsafe
def loop(frames: U32, micros: U32, secs: U32) -> IO(Unit):
  do IO<Unit>:
    dt : U32 <- Godot.frame()
    tick((frames + 1 : U32), (micros + dt : U32), secs,
      f => m => s => loop(f, m, s))

def main() -> IO(Unit):
  do IO<Unit>:
    Godot.print("hello from Bend, inside Godot")
    loop(0, 0, 0)
