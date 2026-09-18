# Bend's own waiting works inside Godot: a sleep parks the program across
# frames instead of stopping the engine, and a forked computation sleeps
# while main keeps taking frames, then hands its answer over a channel.
import Base
import ../godot/Godot.bend as Godot

def worker() -> IO(U32):
  do IO<U32>:
    IO.sleep(80)
    Godot.print("worker: slept")
    return 42

# Frames while the worker sleeps: at 60 a second, 80 ms is a few of them.
def frames(n: Nat, seen: U32) -> IO(U32):
  match n:
    case 0n:
      IO.pure(U32, seen)
    case 1n+p:
      do IO<U32>:
        dt : F32 <- Godot.frame()
        frames(p, (seen + 1 : U32))

def main() -> IO(Unit):
  do IO<Unit>:
    Godot.print("main: sleeping")
    IO.sleep(50)
    Godot.print("main: awake")
    job : Chan(U32) <- IO.fork(U32, worker())
    seen : U32 <- frames(3n, 0)
    Godot.print("main: took " ++ U32.show(seen) ++ " frames meanwhile")
    got : U32 <- IO.join(U32, job)
    Godot.print("main: the worker answered " ++ U32.show(got))
    Godot.print("bend: done")
