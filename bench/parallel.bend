# Bend's parallel calls under Godot: a balanced tree of 2^depth leaves,
# summed with a parallel call at every level. The depth comes from the
# engine at run time, so the compiler cannot fold the sum away. Build it
# with BEND_THREADS=1 and without, and compare the milliseconds.
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
    depth : U32 <- Global.absi(27)
    t0 : Nat <- IO.now()
    +leaves : U32 = pow2(U32.to_nat(depth))
    Godot.print("leaves: " ++ U32.show(leaves))
    t1 : Nat <- IO.now()
    Godot.print("milliseconds: " ++ Nat.show((t1 - t0)))
    Godot.print("bend: done")
