# godot-bend

Write [Godot](https://godotengine.org) games in [Bend 2](https://bend-lang.com),
the language with dependent types, proofs and automatic CPU/GPU parallelism.

```python
import Base
import ../godot/Godot.bend as Godot

def main() -> IO(Unit):
  do IO<Unit>:
    Godot.print("hello from Bend, inside Godot")
```

**Status: a working proof of concept.** A Bend program compiles into a
GDExtension library, Godot loads it, and the program runs frame by frame
inside the engine. The Godot API it can reach is still two effects (`print`
and `frame`). Everything else is the roadmap below. Tested with Godot 4.6.3
on macOS arm64.

## How it works

A Bend binary expects to own its process: `main` builds an `IO` action and
the runtime's event loop runs it to the end. A GDExtension is the opposite:
Godot owns the loop and calls into the library. Two facts about Bend make the
two fit without patching the compiler:

1. `bend main.bend -o main.c` emits **one C file**, and a foreign effect
   (`def f(..) -> IO(T): import "./godot.c"`) is pasted into it. So
   [`godot/godot.c`](godot/godot.c) sees the whole runtime, and can also
   export the GDExtension entry point.
2. The event loop is an interpreter of requests, and an effect may **park**
   its computation (`IO_PARK`) to be resumed later, which is how Bend's own
   channels and sockets wait.

`Godot.frame()` is an effect that parks. The library registers a `BendRuntime`
node: its `_ready` boots the Bend runtime and runs `main` until it parks on
`frame`; its `_process(delta)` answers the parked `frame` with the delta and
pumps the run queue until the program parks again. Every other effect runs
inside that pump, on Godot's main thread, so it can call the engine directly.
Pure Bend code between effects still fans out across every core.

```
Godot main loop ──_process(delta)──▶ BendRuntime ──resume──▶ Bend program
                                                   ◀──park─── Godot.frame()
```

## Try it

Needs [Bun](https://bun.sh) (Bend's compiler runs on it), clang 14+ and
Godot 4.4+.

```sh
git clone --recursive https://github.com/aricarmo/godot-bend
cd godot-bend
tools/build.sh demo/main.bend demo/bin/libgame.dylib
godot --path demo --headless --import
godot --path demo --headless --quit-after 900
```

```
hello from Bend, inside Godot
131 frames in the last second
145 frames in the last second
...
bend: done
```

`bun vendor/bend/bend2/main.ts demo/main.bend` type-checks the same program
and runs it outside the engine, on the JS twins of the effects
([`godot/godot.js`](godot/godot.js)).

## Layout

| Path | What |
|---|---|
| `godot/Godot.bend` | The Bend side: the API a program imports |
| `godot/godot.c` | The host side: effects, the pump, `BendRuntime`, the entry point |
| `godot/godot.js` | JS twins of the effects, for checking and running outside Godot |
| `godot/gdextension_interface.h` | Godot's C API, dumped from 4.6.3 |
| `tools/build.sh` | `.bend` → `.c` → shared library |
| `demo/` | A Godot project that runs `demo/main.bend` |
| `vendor/bend` | The Bend compiler, pinned as a submodule |

## Roadmap

- [x] Bend program loaded as a GDExtension, driven by `_process`
- [ ] `Variant` as a Bend datatype, and objects as opaque handles
- [ ] A dynamic core: `Godot.call(object, method, args)`, get/set property,
      node lookup, instantiate
- [ ] Input and signals delivered to the program as events on `frame`
- [ ] Typed wrappers generated from `extension_api.json` over the dynamic core
- [ ] `F32` deltas (today `frame` answers microseconds as a `U32`)
- [ ] A non-blocking poll in the pump, so `IO.sleep`, sockets and channels
      work inside Godot
- [ ] Linux, then Android and iOS; Windows when Bend supports it
- [ ] Several Bend programs per scene (today: one `BendRuntime`, one `main`)

## Known limits

These come from how the Bend runtime is built today:

- The runtime installs its own `SIGSEGV`/`SIGBUS` handlers and reserves up to
  8 TiB of virtual address space, which iOS is unlikely to allow.
- A runtime failure calls `exit`, which takes the editor down with it.
- The binding reaches into runtime internals (`io_step`, `io_runs`), so it is
  tied to the pinned Bend commit and may need care on each bump.

## License

MIT. Bend is Apache-2.0; `gdextension_interface.h` is part of Godot (MIT).
