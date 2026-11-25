#!/usr/bin/env bash
# Grammar Snake launcher — double-click playable (needs Godot 4.7+).
set -euo pipefail
cd "$(dirname "$0")"

GODOT_BIN="${GODOT:-godot}"
if ! command -v "$GODOT_BIN" >/dev/null 2>&1; then
	# common local spots
	for c in ./Godot_v4.7.2-stable_linux.x86_64 ~/tools/Godot_v4.7.2-stable_linux.x86_64; do
		[ -x "$c" ] && GODOT_BIN="$c" && break
	done
fi

# first run: build .godot import cache (class_name registration etc.)
if [ ! -d .godot ]; then
	"$GODOT_BIN" --headless --path . --import >/dev/null 2>&1 || true
fi

exec "$GODOT_BIN" --path .
