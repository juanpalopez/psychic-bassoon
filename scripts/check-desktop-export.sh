#!/usr/bin/env bash
# Succeeds only when a Godot desktop export is complete: the binary is there and not
# empty, and the game data is either a non-empty .pck beside it (same name, .pck) or
# embedded in the binary (an embedded pck ends with the "GDPC" magic).
#
#   scripts/check-desktop-export.sh build/linux/papercraft-kingdom-defense.x86_64
set -euo pipefail

binary="${1:-}"
[ -n "$binary" ] || { echo "usage: $0 <exported binary>" >&2; exit 2; }

if [ ! -s "$binary" ]; then
  echo "::error::The export did not produce ${binary}." >&2
  exit 1
fi
pck="${binary%.*}.pck"
if [ -s "$pck" ]; then
  echo "Export complete: ${binary} ($(wc -c < "$binary") bytes) and ${pck} ($(wc -c < "$pck") bytes)"
  exit 0
fi
if [ "$(tail -c 4 "$binary")" = "GDPC" ]; then
  echo "Export complete: ${binary} ($(wc -c < "$binary") bytes, pck embedded)"
  exit 0
fi
echo "::error::The export produced ${binary} but no ${pck} and no embedded pck." >&2
exit 1
