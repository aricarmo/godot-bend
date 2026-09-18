#!/bin/sh
# Builds a Bend program into a GDExtension library.
#
#   tools/build.sh demo/main.bend demo/bin/libgame.dylib
#
# Bend emits the whole program, its runtime and godot.c as one C file;
# clang turns that file into the shared library Godot loads. The flags
# follow the ones `bend file.bend -o file` passes (bend2/main.ts), plus
# -shared, and main is renamed since the library has no use for the CLI.
set -e
ROOT=$(cd "$(dirname "$0")/.." && pwd)
SRC=$1
OUT=$2
[ -n "$SRC" ] && [ -n "$OUT" ] || { echo "usage: $0 main.bend out.dylib" >&2; exit 1; }
mkdir -p "$(dirname "$OUT")"
C="${OUT%.*}.c"
BEND_NO_TELEMETRY=1 bun "$ROOT/vendor/bend/bend2/main.ts" "$SRC" -o "$C"
${CC:-clang} -std=c11 -O3 -shared -fPIC -fvisibility=hidden -Dmain=bend_cli_main \
  -I "$ROOT/godot" "$C" -lpthread -lm -o "$OUT"
echo "built $OUT"
