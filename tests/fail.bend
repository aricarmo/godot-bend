# The runtime's fail-stop ends the program, not the game. This program
# makes the runtime give up (a raw pop on an empty stack, which only a bug
# in Godot.bend could do), and the second program, in the same scene,
# keeps taking frames.
import Base
import ../godot/Godot.bend as Godot

def main() -> IO(Unit):
  do IO<Unit>:
    Godot.print("first: about to fail")
    Godot.gd.pop()
    Godot.print("first: never printed")
