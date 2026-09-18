#!/bin/sh
# Builds a Bend program into a GDExtension library.
#
#   tools/build.sh demo/main.bend demo/bin/libgame.dylib   # macOS
#   tools/build.sh demo/main.bend demo/bin/libgame.so      # Linux
#   tools/build.sh demo/main.bend demo/bin/libgame.android.arm64.so android
#   tools/build.sh demo/main.bend demo/bin/libgame.xcframework ios
#
# Bend emits the whole program, its runtime and godot.c as one C file;
# clang turns that file into the shared library Godot loads. The flags
# follow the ones `bend file.bend -o file` passes (bend2/main.ts), plus
# -shared, and main is renamed since the library has no use for the CLI.
#
# A scene with several Bend programs needs a library each, and each its own
# node class: BEND_CLASS=Enemy names it (the default is BendRuntime).
#
# The android target cross-compiles for arm64 with the NDK's clang, found
# through ANDROID_NDK_HOME or as the newest NDK of the Android SDK. Bionic
# keeps pthreads inside libc, so that one links without -lpthread.
#
# iOS loads no loose dylib, so the ios target makes what godot-cpp makes
# there: a static library per slice (the device, and the simulator for
# both arm64 and x86_64, which is all the official 4.6 template links) in
# one .xcframework. Godot's export links it into the app and registers the
# entry symbol.
set -e
ROOT=$(cd "$(dirname "$0")/.." && pwd)
SRC=$1
OUT=$2
TARGET=${3:-host}
[ -n "$SRC" ] && [ -n "$OUT" ] || { echo "usage: $0 main.bend out [android|ios]" >&2; exit 1; }
mkdir -p "$(dirname "$OUT")"
C="${OUT%.*}.c"
CLASS="-DGD_CLASS=\"${BEND_CLASS:-BendRuntime}\""
# The runtime's fail-stop lands in godot.c instead of ending the process.
TRAP="-D_exit(c)=gd_exit(c)"
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
if [ "$TARGET" = ios ]; then
  TMP=$(mktemp -d)
  trap 'rm -rf "$TMP"' EXIT
  slice() { # name, sdk, clang target
    mkdir -p "$TMP/$1"
    xcrun --sdk "$2" clang -target "$3" -std=c11 -O3 -fvisibility=hidden \
      -Dmain=bend_cli_main "$CLASS" "$TRAP" -I "$ROOT/godot" -c "$C" \
      -o "$TMP/$1/libgame.o"
    xcrun ar rcs "$TMP/$1/libgame.a" "$TMP/$1/libgame.o"
  }
  slice device iphoneos arm64-apple-ios14.0
  slice sim-arm64 iphonesimulator arm64-apple-ios14.0-simulator
  slice sim-x86_64 iphonesimulator x86_64-apple-ios14.0-simulator
  mkdir -p "$TMP/sim"
  xcrun lipo -create "$TMP/sim-arm64/libgame.a" "$TMP/sim-x86_64/libgame.a" \
    -output "$TMP/sim/libgame.a"
  rm -rf "$OUT"
  xcodebuild -create-xcframework -library "$TMP/device/libgame.a" \
    -library "$TMP/sim/libgame.a" -output "$OUT" >/dev/null
  echo "built $OUT"
  exit 0
fi
"$CC" -std=c11 -O3 -shared -fPIC -fvisibility=hidden -Dmain=bend_cli_main \
  "$CLASS" "$TRAP" -I "$ROOT/godot" "$C" $LIBS -o "$OUT"
echo "built $OUT"
