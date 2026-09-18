# Godot
# =====

# Bend bindings for the Godot engine. Import this file as Godot:
#
#   import ../godot/Godot.bend as Godot
#
# The gd.* defs are the raw effects, filled by godot.c; their names are
# what the C side sees (gd.print is CID_GD_PRINT and gd_print_run), and an
# import alias does not reach them, hence the prefix. The defs below them
# are the API a program uses, so a program writes Godot.print.
import Base

def gd.print(text: String) -> IO(Unit):
  import "./godot.c"
  import "./godot.js"

def gd.frame() -> IO(U32):
  import "./godot.c"
  import "./godot.js"

# Prints through Godot: the text reaches the editor's Output panel.
def print(text: String) -> IO(Unit):
  gd.print(text)

# Waits for the next frame and answers the microseconds since the last
# one. A program that never calls frame runs to its end inside _ready.
def frame() -> IO(U32):
  gd.frame()
