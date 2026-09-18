#!/bin/sh
# Builds a Bend program into a GDExtension library.
#
#   tools/build.sh demo/main.bend demo/bin/libgame.dylib   # macOS
#   tools/build.sh demo/main.bend demo/bin/libgame.so      # Linux
#   tools/build.sh demo/main.bend demo/bin/libgame.android.arm64.so android
#
# Bend emits the whole program, its runtime and godot.c as one C file;
# clang turns that file into the shared library Godot loads. The flags
# follow the ones `bend file.bend -o file` passes (bend2/main.ts), plus
# -shared, and main is renamed since the library has no use for the CLI.
#
# The android target cross-compiles for arm64 with the NDK's clang, found
# through ANDROID_NDK_HOME or as the newest NDK of the Android SDK. Bionic
# keeps pthreads inside libc, so that one links without -lpthread.
set -e
ROOT=$(cd "$(dirname "$0")/.." && pwd)
SRC=$1
OUT=$2
TARGET=${3:-host}
[ -n "$SRC" ] && [ -n "$OUT" ] || { echo "usage: $0 main.bend out.so [android]" >&2; exit 1; }
mkdir -p "$(dirname "$OUT")"
C="${OUT%.*}.c"
LIBS="-lpthread -lm"
CC=${CC:-clang}
if [ "$TARGET" = android ]; then
  SDK=${ANDROID_HOME:-${ANDROID_SDK_ROOT:-$HOME/Library/Android/sdk}}
  NDK=${ANDROID_NDK_HOME:-$(ls -d "$SDK"/ndk/* 2>/dev/null | sort -V | tail -1)}
  CC=$(ls "$NDK"/toolchains/llvm/prebuilt/*/bin/aarch64-linux-android24-clang 2>/dev/null | head -1)
  [ -x "$CC" ] || { echo "no Android NDK found; set ANDROID_NDK_HOME" >&2; exit 1; }
  LIBS="-lm"
fi
BEND_NO_TELEMETRY=1 bun "$ROOT/vendor/bend/bend2/main.ts" "$SRC" -o "$C"
"$CC" -std=c11 -O3 -shared -fPIC -fvisibility=hidden -Dmain=bend_cli_main \
  -I "$ROOT/godot" "$C" $LIBS -o "$OUT"
echo "built $OUT"
