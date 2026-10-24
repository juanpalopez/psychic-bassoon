#!/usr/bin/env bash
# Runs the whole GUT suite as a work queue, N Godot processes at a time. The suite is
# single-threaded per process, so N workers take about 1/N of the serial time on an N-core
# machine. Prints the summary, every failure, and the slowest scripts.
#
# Order and batching come from scripts/gut-times.json (script path -> seconds; GUT_TIMES_FILE
# overrides it). Scripts with no entry run first (largest file first, since their cost is
# unknown), then the recorded ones, longest first. Recorded scripts under 5 s (GUT_BATCH_SECONDS)
# go last, in batches of 8 (GUT_BATCH_SIZE), one process per batch, so the ~2 s Godot start is
# paid once; a failing batch is reported with its log. A missing, empty or stale file only costs
# speed, never a run.
#
# usage: scripts/run-gut-parallel.sh            # one worker per core, up to 8
#        scripts/run-gut-parallel.sh -j 4       # four workers
#        scripts/run-gut-parallel.sh -t res://tests/a/test_x.gd,res://tests/b/test_y.gd
#                                               # only these scripts (what scripts/select-tests.mjs
#                                               # prints for a pull request), same checks and exit code
#        scripts/run-gut-parallel.sh --write-times
#                                               # one process per script (no batching), then rewrite
#                                               # scripts/gut-times.json from the run if it passed
set -u
cd "$(dirname "$0")/.."
jobs=0
tests=""
write_times=0
while [ "$#" -gt 0 ]; do
  case "$1" in
    -j) jobs="${2:?-j needs a number}"; shift 2 ;;
    -t) tests="${2:?-t needs a comma-separated list of res:// test paths}"; shift 2 ;;
    --write-times) write_times=1; shift ;;
    *) echo "usage: $0 [-j workers] [--write-times] [-t res://tests/test_a.gd,res://tests/test_b.gd]" >&2; exit 2 ;;
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
  find godot/tests -name 'test_*.gd' >"$dir/scripts.txt"
fi
times_file="${GUT_TIMES_FILE:-scripts/gut-times.json}"
# "path seconds" lines; a missing or unreadable file gives none
{ grep -oE '"[^"]+" *: *[0-9.]+' "$times_file" 2>/dev/null || true; } \
  | sed -E 's/^"([^"]+)" *: *([0-9.]+)$/\1 \2/' >"$dir/known.txt"
# "S <sort key> <path>" for a script of its own, "B <path>" for one to batch
while read -r path; do echo "$(wc -c <"$path") $path"; done <"$dir/scripts.txt" \
  | awk -v known="$dir/known.txt" -v limit="${GUT_BATCH_SECONDS:-5}" -v batch="$((1 - write_times))" '
    BEGIN { while ((getline line < known) > 0) { split(line, f, " "); t[f[1]] = f[2] } }
    $2 in t { if (batch && t[$2] + 0 < limit) print "B", $2; else print "S", t[$2], $2; next }
    { print "S", 1000000 + $1, $2 }' >"$dir/plan.txt"
# queue lines "<id> <res:// path>[,<res:// path>...]": solo scripts longest first, batches last
{
  grep '^S ' "$dir/plan.txt" | sort -rn -k2,2 | awk '{print "res://" substr($3, 7)}'
  grep '^B ' "$dir/plan.txt" | awk -v size="${GUT_BATCH_SIZE:-8}" '
    { grp = grp (grp == "" ? "" : ",") "res://" substr($2, 7) }
    NR % size == 0 { print grp; grp = "" }
    END { if (grp != "") print grp }'
} | awk '{print NR, $0}' >"$dir/queue.txt"
run_one() {
  id="$1"
  list="$2"
  start=$(date +%s)
  "$GODOT_BIN" --headless --path godot -s addons/gut/gut_cmdln.gd -gconfig= -glog=1 \
    -gtest="$list" -gexit >"$dir/godot_tests_$id.log" 2>&1
  echo "$?" >"$dir/godot_tests_$id.rc"
  echo "$(( $(date +%s) - start )) $list" >>"$dir/times.txt"
}
export -f run_one
xargs -P "$jobs" -L1 bash -c 'run_one "$0" "$1"' <"$dir/queue.txt"
status=0
for log in "$dir"/godot_tests_*.log; do
  rc="$(cat "${log%.log}.rc" 2>/dev/null || echo 1)"
  # a crash exits non-zero or leaves no summary; the rest of its batch never ran
  if [ "$rc" != 0 ] || ! grep -qE "^(Passing|Failing) Tests" "$log" \
    || grep -qE "Failing Tests|Parse Error|SCRIPT ERROR" "$log"; then
    status=1
    echo "failure in $log (godot exit code $rc)"
    # the scripts of the run, then the distinct failure lines
    grep -E "^res://.*\.gd" "$log" | cut -c1-200 | sort -u
    grep -E "Failed|Failing Tests|at line|SCRIPT ERROR|Parse Error" "$log" | cut -c1-200 | sort -u | head -20
  fi
done
cat "$dir"/godot_tests_*.log | grep -E "^(Passing|Failing) Tests" \
  | awk '{n[$1]+=$3} END{print "Passing Tests", n["Passing"]+0; print "Failing Tests", n["Failing"]+0}'
echo "slowest scripts (seconds):"
sort -rn "$dir/times.txt" | head -8
if [ "$write_times" = 1 ] && [ "$status" = 0 ]; then
  # this run's seconds win over the old entries; scripts that no longer exist are dropped
  { cat "$dir/known.txt"; awk '{print "godot/" substr($2, 7), $1}' "$dir/times.txt"; } \
    | awk '{t[$1] = $2} END {for (p in t) print p, t[p]}' | sort \
    | while read -r p t; do [ -f "$p" ] && echo "$p $t"; done \
    | awk 'BEGIN {print "{"} {printf "%s  \"%s\": %s", (NR > 1 ? ",\n" : ""), $1, $2} END {print "\n}"}' \
    >"$dir/new-times.json" && mv "$dir/new-times.json" "$times_file"
  echo "wrote $times_file"
fi
echo "logs: $dir"
exit "$status"
