#!/bin/sh
# Runs every tests/*.bend inside a headless Godot and compares what it
# prints with the .out beside it. GODOT names the engine's binary.
#
#   GODOT=/Applications/Godot.app/Contents/MacOS/Godot tools/test.sh
set -e
ROOT=$(cd "$(dirname "$0")/.." && pwd)
GODOT=${GODOT:-godot}
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
cp "$ROOT/demo/project.godot" "$ROOT/demo/game.gdextension" \
  "$ROOT/demo/main.tscn" "$WORK"
fail=0
for t in "$ROOT"/tests/*.bend; do
  "$ROOT/tools/build.sh" "$t" "$WORK/bin/libgame.dylib" >/dev/null
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
