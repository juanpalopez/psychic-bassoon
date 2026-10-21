#!/usr/bin/env bash
# Runs the whole GUT suite as a work queue: one Godot process per test script, N at a time, the
# biggest scripts first so the slowest do not start last. The suite is single-threaded per
# process, so N workers take about 1/N of the serial time on an N-core machine. Prints the
# summary, every failure, and the slowest scripts.
#
# usage: scripts/run-gut-parallel.sh            # one worker per core, up to 8
#        scripts/run-gut-parallel.sh -j 4       # four workers
set -u
cd "$(dirname "$0")/.."
jobs=0
if [ "${1:-}" = "-j" ]; then jobs="$2"; shift 2; fi
if [ "$jobs" -le 0 ]; then
  jobs=$(sysctl -n hw.ncpu 2>/dev/null || nproc 2>/dev/null || echo 4)
  [ "$jobs" -gt 8 ] && jobs=8
fi
dir="$(mktemp -d /tmp/gut-par.XXXXXX)"
export dir
godot --headless --path godot --import >/dev/null 2>&1
# biggest first
find godot/tests -name 'test_*.gd' -exec wc -c {} + | grep -v ' total$' | sort -rn \
  | awk '{print $2}' >"$dir/scripts.txt"
run_one() {
  path="$1"
  name="$(echo "$path" | tr '/' '_')"
  start=$(date +%s)
  godot --headless --path godot -s addons/gut/gut_cmdln.gd -gconfig= -glog=1 \
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
