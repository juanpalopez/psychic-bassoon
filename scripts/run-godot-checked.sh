#!/usr/bin/env bash
# Runs a Godot command with a time limit, keeps its output in a log, and fails when the
# command exits non-zero, runs out of time, or logs an engine error (`ERROR:`,
# `SCRIPT ERROR:` or `SHADER ERROR:` at the start of a line). Godot's headless runs often
# exit 0 after such errors (`--import` does when a script fails to parse; a crash in
# `_ready` or a shader that does not compile only shows in the log), so the log decides.
#
#   scripts/run-godot-checked.sh <seconds> <log file> -- <command> [args...]
set -uo pipefail

usage() {
  echo "usage: $0 <seconds> <log file> -- <command> [args...]" >&2
  exit 2
}
[ "$#" -ge 4 ] || usage
limit="$1"
log="$2"
[ "$3" = "--" ] || usage
shift 3
[[ "$limit" =~ ^[0-9]+$ ]] || usage

timeout "$limit" "$@" > "$log" 2>&1
status=$?
cat "$log"
if [ "$status" -eq 124 ]; then
  echo "::error::$1 ran out of its ${limit} s limit" >&2
  exit 1
fi
if [ "$status" -ne 0 ]; then
  echo "::error::$1 exited with ${status}" >&2
  exit 1
fi
if grep -nE '^(ERROR|SCRIPT ERROR|SHADER ERROR):' "$log" >&2; then
  echo "::error::$1 logged engine errors (above)" >&2
  exit 1
fi
exit 0
