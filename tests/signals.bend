# Signals reach the program as a queue. A user signal emitted from inside
# a call (the reentrant case) arrives with its arguments in order, two
# emits keep their order, and a Timer's timeout arrives some frames later.
import Base
import ../godot/Godot.bend as Godot

def arg(v: Godot.Variant) -> String:
  match v:
    case Godot.VInt{v}:
      U32.show(v)
    case Godot.VStr{v}:
      v
    case other:
      "?"

def args(vs: List<Godot.Variant>) -> String:
  match vs:
    case []:
      ""
    case v <> rest:
      " " ++ arg(v) ++ args(rest)

def line(s: Godot.Signal) -> String:
  Godot.Signal{tag, vs} = s
  "signal " ++ U32.show(tag) ++ ":" ++ args(vs)

def say(ss: List<Godot.Signal>) -> IO(Unit):
  match ss:
    case []:
      IO.pure(Unit, Unit{})
    case s <> rest:
      do IO<Unit>:
        Godot.print(line(s))
        say(rest)

# The frame's signals: none yet means wait on, through rest (a def cannot
# name one defined below it).
def tail(ss: List<Godot.Signal>, rest: IO(Unit)) -> IO(Unit):
  match ss:
    case []:
      rest
    case s <> more:
      do IO<Unit>:
        say(s <> more)
        Godot.print("bend: done")

# Frames until the timer fires, at most fuel of them.
def wait(fuel: Nat) -> IO(Unit):
  match fuel:
    case 0n:
      Godot.print("the timer never fired")
    case 1n+p:
      do IO<Unit>:
        dt : F32 <- Godot.frame()
        ss : List<Godot.Signal> <- Godot.signals()
        tail(ss, wait(p))

def main() -> IO(Unit):
  do IO<Unit>:
    +me : Godot.Object <- Godot.self()
    a : Godot.Variant <- Godot.call(me, "add_user_signal", [Godot.VStr{"hit"}])
    Godot.connect(me, "hit", 7)
    b : Godot.Variant <- Godot.call(me, "emit_signal", [Godot.VStr{"hit"}, Godot.VInt{42}, Godot.VStr{"left"}])
    c : Godot.Variant <- Godot.call(me, "emit_signal", [Godot.VStr{"hit"}, Godot.VInt{43}])
    first : List<Godot.Signal> <- Godot.signals()
    say(first)
    none : List<Godot.Signal> <- Godot.signals()
    say(none)
    Godot.connect(me, "no_such_signal", 9)
    +timer : Godot.Object <- Godot.new("Timer")
    Godot.set(timer, "wait_time", Godot.VFloat{0.05})
    Godot.set(timer, "one_shot", Godot.VBool{True{}})
    d : Godot.Variant <- Godot.call(me, "add_child", [Godot.VObj{timer}])
    Godot.connect(timer, "timeout", 8)
    e : Godot.Variant <- Godot.call(timer, "start", [])
    wait(600n)
