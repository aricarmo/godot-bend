# Bend's sockets work inside Godot: one program listens, forks a server
# that echoes one message, and connects to itself over loopback. Accept,
# connect, send and recv all park, and Godot's frames wake them.
import Base
import ../godot/Godot.bend as Godot

def closed(m: Socket & Result<&1, &1, U32 & String, Unit>) -> IO(Unit):
  (s, r) = m
  Socket.close(s)

def reply(got: Socket & Result<&1, &1, U32 & String, String>) -> IO(Unit):
  (s, r) = got
  match r:
    case Done{text}:
      do IO<Unit>:
        Godot.print("server: answering")
        sent : Socket & Result<&1, &1, U32 & String, Unit> <- TCP.send(s, "echo of " ++ text)
        closed(sent)
    case Fail{e}:
      Socket.close(s)

def serve(got: Listener & Result<&1, &1, U32 & String, Socket>) -> IO(Unit):
  (l, r) = got
  match r:
    case Done{s}:
      do IO<Unit>:
        Listener.close(l)
        said : Socket & Result<&1, &1, U32 & String, String> <- TCP.recv(s, 64)
        reply(said)
    case Fail{e}:
      Listener.close(l)

def server(l: Listener) -> IO(Unit):
  do IO<Unit>:
    got : Listener & Result<&1, &1, U32 & String, Socket> <- TCP.accept(l)
    serve(got)

def answer(got: Socket & Result<&1, &1, U32 & String, String>) -> IO(Unit):
  (s, r) = got
  match r:
    case Done{text}:
      do IO<Unit>:
        Godot.print("client got: " ++ text)
        Socket.close(s)
    case Fail{e}:
      do IO<Unit>:
        Godot.print("client: recv failed")
        Socket.close(s)

def ask(m: Socket & Result<&1, &1, U32 & String, Unit>) -> IO(Unit):
  (s, r) = m
  do IO<Unit>:
    got : Socket & Result<&1, &1, U32 & String, String> <- TCP.recv(s, 64)
    answer(got)

def main() -> IO(Unit):
  do IO<Unit>:
    l : Listener <- IO.try(Listener, TCP.listen(47811))
    job : Chan(Unit) <- IO.fork(Unit, server(l))
    s : Socket <- IO.try(Socket, TCP.connect("127.0.0.1", 47811))
    sent : Socket & Result<&1, &1, U32 & String, Unit> <- TCP.send(s, "ping")
    ask(sent)
    u : Unit <- IO.join(Unit, job)
    Godot.print("bend: done")
