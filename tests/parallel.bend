# Bend's parallel calls run under Godot: every level of this sum forks,
# so the runtime's worker threads start inside the engine, and the answer
# comes back right. bench/parallel.bend is the same program, timed.
import Base
import ../godot/Godot.bend as Godot
import ../godot/api/Global.bend as Global

def pow2(+n: Nat) -> U32:
  match n:
    case 0n:
      1
    case 1n+p:
      a b = pow2(p) pow2(p) # parallel call
      (a + b : U32)

def main() -> IO(Unit):
  do IO<Unit>:
    depth : U32 <- Global.absi(22)
    Godot.print("leaves: " ++ U32.show(pow2(U32.to_nat(depth))))
    dt : F32 <- Godot.frame()
    Godot.print("and the engine goes on")
    Godot.print("bend: done")
