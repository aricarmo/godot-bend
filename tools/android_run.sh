#!/bin/sh
# Runs a Bend program on the Android device or emulator adb sees, and
# prints what it printed.
#
#   GODOT=/path/to/godot tools/android_run.sh tests/tcp.bend [seconds]
#
# It builds the program for arm64, wraps it in a throwaway Godot project,
# exports a debug APK (the editor must have the Android export set up: SDK,
# debug keystore, export templates), installs it, launches it, and shows
# Godot's log after the wait (10 seconds unless told).
set -e
ROOT=$(cd "$(dirname "$0")/.." && pwd)
GODOT=${GODOT:-godot}
ADB=${ADB:-$(command -v adb || echo "$HOME/Library/Android/sdk/platform-tools/adb")}
SRC=$1
WAIT=${2:-10}
[ -n "$SRC" ] || { echo "usage: $0 main.bend [seconds]" >&2; exit 1; }
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
"$ROOT/tools/build.sh" "$SRC" "$WORK/bin/libgame.android.arm64.so" android >/dev/null
cp "$ROOT/demo/main.tscn" "$ROOT/demo/icon.svg" "$WORK"
cat > "$WORK/project.godot" <<'END'
config_version=5

[application]

config/name="godot-bend run"
run/main_scene="res://main.tscn"
config/features=PackedStringArray("4.6")
config/icon="res://icon.svg"

[rendering]

renderer/rendering_method="gl_compatibility"
renderer/rendering_method.mobile="gl_compatibility"
textures/vram_compression/import_etc2_astc=true
END
cat > "$WORK/game.gdextension" <<'END'
[configuration]

entry_symbol = "godot_bend_init"
compatibility_minimum = "4.4"

[libraries]

android.arm64 = "res://bin/libgame.android.arm64.so"
END
cat > "$WORK/export_presets.cfg" <<'END'
[preset.0]

name="Android"
platform="Android"
runnable=true
export_filter="all_resources"
export_path="run.apk"

[preset.0.options]

gradle_build/use_gradle_build=false
architectures/armeabi-v7a=false
architectures/arm64-v8a=true
architectures/x86=false
architectures/x86_64=false
package/unique_name="org.godotbend.run"
package/name="godot-bend run"
package/signed=true
permissions/internet=true
END
sh -c '"$0" --path "$1" --headless --import >/dev/null 2>&1' "$GODOT" "$WORK" 2>/dev/null || true
"$GODOT" --path "$WORK" --headless --export-debug Android "$WORK/run.apk" >/dev/null 2>&1
[ -f "$WORK/run.apk" ] || { echo "the export made no APK; is Android export set up in the editor?" >&2; exit 1; }
"$ADB" install -r "$WORK/run.apk" >/dev/null
"$ADB" logcat -c
"$ADB" shell monkey -p org.godotbend.run -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1
sleep "$WAIT"
"$ADB" logcat -d -s godot:V | sed -n 's/^.* godot *: //p' | grep '[[:alnum:]]' \
  | grep -v '^Godot Engine\|^OpenGL\|^Vulkan'
"$ADB" shell am force-stop org.godotbend.run
