# A dropped handle names nothing, even after its row is taken again, and
# input events arrive as values once the program listens: a key press fed
# through Input.parse_input_event comes back as a key signal.
import Base
import ../godot/Godot.bend as Godot

def word(v: Godot.Variant) -> String:
  match v:
    case Godot.VNil{}:
      "nil"
    case Godot.VStr{v}:
      v
    case Godot.VInt{v}:
      U32.show(v)
    case Godot.VBool{True{}}:
      "true"
    case Godot.VBool{False{}}:
      "false"
    case other:
      "?"

def words(vs: List<&2, Godot.Variant>) -> String:
  match vs:
    case []:
      ""
    case v <> rest:
      " " ++ word(v) ++ words(rest)

def line(s: Godot.Signal) -> String:
  Godot.Signal{tag, vs} = s
  "signal " ++ U32.show(tag) ++ ":" ++ words(vs)

def say(ss: List<&2, Godot.Signal>) -> IO(Unit):
  match ss:
    case []:
      IO.pure(Unit, Unit{})
    case s <> rest:
      do IO<Unit>:
        Godot.print(line(s))
        say(rest)

def tail(ss: List<&2, Godot.Signal>, rest: IO(Unit)) -> IO(Unit):
  match ss:
    case []:
      rest
    case s <> more:
      do IO<Unit>:
        say(s <> more)
        Godot.print("bend: done")

def wait(fuel: Nat) -> IO(Unit):
  match fuel:
    case 0n:
      Godot.print("no input arrived")
    case 1n+p:
      do IO<Unit>:
        dt : F32 <- Godot.frame()
        ss : List<&2, Godot.Signal> <- Godot.signals()
        tail(ss, wait(p))

def main() -> IO(Unit):
  do IO<Unit>:
    +old : Godot.Object <- Godot.new("Node")
    Godot.set(old, "name", Godot.VStr{"Old"})
    a : Godot.Variant <- Godot.get(old, "name")
    Godot.print("held: " ++ word(a))
    gone : Godot.Variant <- Godot.call(old, "free", [])
    Godot.drop(old)
    b : Godot.Variant <- Godot.get(old, "name")
    Godot.print("dropped: " ++ word(b))
    +new : Godot.Object <- Godot.new("Node")
    Godot.set(new, "name", Godot.VStr{"New"})
    c : Godot.Variant <- Godot.get(old, "name")
    d : Godot.Variant <- Godot.get(new, "name")
    Godot.print("old handle, row taken again: " ++ word(c))
    Godot.print("new handle: " ++ word(d))
    freed : Godot.Variant <- Godot.call(new, "free", [])
    Godot.listen(True{})
    +press : Godot.Object <- Godot.new("InputEventKey")
    Godot.set(press, "keycode", Godot.VInt{87})
    Godot.set(press, "pressed", Godot.VBool{True{}})
    input : Godot.Object <- Godot.singleton("Input")
    e : Godot.Variant <- Godot.call(input, "parse_input_event", [Godot.VObj{press}])
    Godot.drop(press)
    wait(120n)
