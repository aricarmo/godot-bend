# A program that ends itself with IO.die: its message goes to stderr, its
# code to Godot's log, and the engine goes on.
import Base
import ../godot/Godot.bend as Godot

def main() -> IO(Unit):
  do IO<Unit>:
    Godot.print("about to die")
    IO.die(Unit, 3, "gave up")
