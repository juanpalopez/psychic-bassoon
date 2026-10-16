#!/usr/bin/env bash
# Runs the whole GUT suite (or the scripts you select) with the output in a file, then prints
# the summary and every failure. Piping a long headless Godot run through grep in the
# foreground can hang a tool, so the run writes to a log first.
#
# usage: scripts/run-gut.sh                      # every test
#        scripts/run-gut.sh -gselect=test_win    # one script (extra args go to GUT)
set -u
cd "$(dirname "$0")/.."
log="$(mktemp /tmp/gut.XXXXXX)"
godot --headless --path godot --import >/dev/null 2>&1
godot --headless --path godot -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit "$@" >"$log" 2>&1
grep -E "Failed|Passing Tests|Failing Tests|at line|SCRIPT ERROR|Parse Error" "$log" | head -40
echo "full log: $log"
! grep -qE "Failing Tests|Parse Error|SCRIPT ERROR" "$log"
