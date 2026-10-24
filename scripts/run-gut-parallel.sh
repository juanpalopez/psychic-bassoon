#!/usr/bin/env bash
# Runs the whole GUT suite as a work queue: one Godot process per test script, N at a time, the
# biggest scripts first so the slowest do not start last. The suite is single-threaded per
# process, so N workers take about 1/N of the serial time on an N-core machine. Prints the
# summary, every failure, and the slowest scripts.
#
# usage: scripts/run-gut-parallel.sh            # one worker per core, up to 8
#        scripts/run-gut-parallel.sh -j 4       # four workers
#        scripts/run-gut-parallel.sh -t res://tests/a/test_x.gd,res://tests/b/test_y.gd
#                                               # only these scripts (what scripts/select-tests.mjs
#                                               # prints for a pull request), same checks and exit code
set -u
cd "$(dirname "$0")/.."
jobs=0
tests=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    -j) jobs="${2:?-j needs a number}"; shift 2 ;;
    -t) tests="${2:?-t needs a comma-separated list of res:// test paths}"; shift 2 ;;
    *) echo "usage: $0 [-j workers] [-t res://tests/test_a.gd,res://tests/test_b.gd]" >&2; exit 2 ;;
  esac
done
if [ "$jobs" -le 0 ]; then
  jobs=$(sysctl -n hw.ncpu 2>/dev/null || nproc 2>/dev/null || echo 4)
  [ "$jobs" -gt 8 ] && jobs=8
fi
dir="$(mktemp -d /tmp/gut-par.XXXXXX)"
# the Godot binary: CI sets GODOT, a developer machine has `godot` on the PATH
export GODOT_BIN="${GODOT:-godot}"
export dir
"$GODOT_BIN" --headless --path godot --import >/dev/null 2>&1
if [ -n "$tests" ]; then
  # an explicit list: a path that does not exist fails here instead of silently running nothing
  : >"$dir/scripts.txt"
  for res in $(echo "$tests" | tr ',' ' '); do
    path="godot/${res#res://}"
    if [ "$res" = "$path" ] || [ ! -f "$path" ]; then
      echo "run-gut-parallel: no test script at $res" >&2
      exit 2
    fi
    echo "$path" >>"$dir/scripts.txt"
  done
else
  # biggest first
  find godot/tests -name 'test_*.gd' -exec wc -c {} + | grep -v ' total$' | sort -rn \
    | awk '{print $2}' >"$dir/scripts.txt"
fi
run_one() {
  path="$1"
  name="$(echo "$path" | tr '/' '_')"
  start=$(date +%s)
  "$GODOT_BIN" --headless --path godot -s addons/gut/gut_cmdln.gd -gconfig= -glog=1 \
    -gtest="res://${path#godot/}" -gexit >"$dir/$name.log" 2>&1
  echo "$(( $(date +%s) - start )) $path" >>"$dir/times.txt"
}
export -f run_one
xargs -P "$jobs" -I{} bash -c 'run_one {}' <"$dir/scripts.txt"
status=0
for log in "$dir"/godot_tests_*.log; do
  if grep -qE "Failing Tests|Parse Error|SCRIPT ERROR" "$log"; then
    status=1
    grep -E "Failed|Failing Tests|at line|SCRIPT ERROR|Parse Error" "$log" | cut -c1-200 | head -20
  fi
done
cat "$dir"/godot_tests_*.log | grep -E "^(Passing|Failing) Tests" \
  | awk '{n[$1]+=$3} END{print "Passing Tests", n["Passing"]+0; print "Failing Tests", n["Failing"]+0}'
echo "slowest scripts (seconds):"
sort -rn "$dir/times.txt" | head -8
echo "logs: $dir"
exit "$status"
