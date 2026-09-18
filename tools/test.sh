#!/bin/sh
# Runs every tests/*.bend inside a headless Godot and compares what it
# prints with the .out beside it. GODOT names the engine's binary.
#
#   GODOT=/Applications/Godot.app/Contents/MacOS/Godot tools/test.sh
set -e
ROOT=$(cd "$(dirname "$0")/.." && pwd)
GODOT=${GODOT:-godot}
case $(uname -s) in Darwin) LIB=libgame.dylib;; *) LIB=libgame.so;; esac
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
cp "$ROOT/demo/project.godot" "$ROOT/demo/game.gdextension" \
  "$ROOT/demo/main.tscn" "$WORK"
fail=0
for t in "$ROOT"/tests/*.bend; do
  case $t in *.second.bend) continue;; esac
  # tests/NAME.second.bend is a second program for the same scene: its own
  # library and node class (BendSecond), a child of the first one's node.
  cp "$ROOT/demo/main.tscn" "$WORK/main.tscn"
  rm -rf "$WORK/.godot" "$WORK/second.gdextension" "$WORK/bin/second.$LIB"
  if [ -f "${t%.bend}.second.bend" ]; then
    BEND_CLASS=BendSecond "$ROOT/tools/build.sh" "${t%.bend}.second.bend" \
      "$WORK/bin/second.$LIB" >/dev/null
    cat > "$WORK/second.gdextension" <<END
[configuration]

entry_symbol = "godot_bend_init"
compatibility_minimum = "4.4"

[libraries]

macos = "res://bin/second.$LIB"
linux.x86_64 = "res://bin/second.$LIB"
linux.arm64 = "res://bin/second.$LIB"
END
    printf '\n[node name="Second" type="BendSecond" parent="."]\n' >> "$WORK/main.tscn"
  fi
  "$ROOT/tools/build.sh" "$t" "$WORK/bin/$LIB" >/dev/null
  # The first headless import of a project with any GDExtension crashes
  # at shutdown (godotengine/godot#123511), after the import is done.
  sh -c '"$0" --path "$1" --headless --import >/dev/null 2>&1' \
    "$GODOT" "$WORK" 2>/dev/null || true
  "$GODOT" --path "$WORK" --headless --quit-after 200 2>&1 \
    | grep '[[:alnum:]]' | grep -v '^   at:\|^Godot Engine' > "$WORK/got" \
    || true
  if diff -u "${t%.bend}.out" "$WORK/got"; then
    echo "ok   $(basename "$t")"
  else
    echo "FAIL $(basename "$t")"
    fail=1
  fi
done
exit $fail
