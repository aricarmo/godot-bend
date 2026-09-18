# The second program of tests/fail.bend: still here after the first one
# is gone.
import Base
import ../godot/Godot.bend as Godot

def frames(n: Nat) -> IO(Unit):
  match n:
    case 0n:
      Godot.print("second: still running")
    case 1n+p:
      do IO<Unit>:
        dt : F32 <- Godot.frame()
        frames(p)

def main() -> IO(Unit):
  do IO<Unit>:
    Godot.print("second: started")
    frames(5n)
