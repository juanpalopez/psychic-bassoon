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
#        scripts/run-gut-parallel.sh --shard 1/4
#                                               # only shard 1 of 4 (0-based; CI runs one per matrix
#                                               # job). The list (all scripts, or -t) is dealt out
#                                               # greedily by recorded seconds, longest first onto the
#                                               # least-loaded shard, ties by path, so every shard sees
#                                               # the same split on every machine. A script with no
#                                               # entry weighs GUT_UNKNOWN_SECONDS (20). An empty shard
#                                               # exits 0.
#        scripts/run-gut-parallel.sh --write-times
#                                               # one process per script (no batching), then rewrite
#                                               # scripts/gut-times.json from the run if it passed
set -u
cd "$(dirname "$0")/.."
jobs=0
tests=""
write_times=0
shard=""
shards=1
while [ "$#" -gt 0 ]; do
  case "$1" in
    -j) jobs="${2:?-j needs a number}"; shift 2 ;;
    -t) tests="${2:?-t needs a comma-separated list of res:// test paths}"; shift 2 ;;
    --write-times) write_times=1; shift ;;
    --shard)
      shard="${2:?--shard needs i/n}"; shift 2
      shards="${shard#*/}"; shard="${shard%/*}"
      case "$shard$shards" in ''|*[!0-9]*) echo "run-gut-parallel: --shard wants i/n, e.g. 0/4" >&2; exit 2 ;; esac
      if [ "$shards" -lt 1 ] || [ "$shard" -ge "$shards" ]; then
        echo "run-gut-parallel: --shard i/n needs 0 <= i < n" >&2; exit 2
      fi ;;
    *) echo "usage: $0 [-j workers] [--shard i/n] [--write-times] [-t res://tests/test_a.gd,res://tests/test_b.gd]" >&2; exit 2 ;;
  esac
done
if [ -n "$shard" ] && [ "$write_times" = 1 ]; then
  echo "run-gut-parallel: --write-times needs the whole suite, not a shard" >&2
  exit 2
fi
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
if [ -n "$shard" ]; then
  # greedy split: heaviest first onto the least-loaded shard (lowest index on a tie)
  LC_ALL=C awk -v known="$dir/known.txt" -v dflt="${GUT_UNKNOWN_SECONDS:-20}" '
    BEGIN { while ((getline line < known) > 0) { split(line, f, " "); t[f[1]] = f[2] } }
    { print (($1 in t) ? t[$1] : dflt), $1 }' "$dir/scripts.txt" \
    | LC_ALL=C sort -k1,1nr -k2,2 \
    | awk -v n="$shards" -v me="$shard" '
      { best = 0; for (i = 1; i < n; i++) if (load[i] < load[best]) best = i
        load[best] += $1; if (best == me) print $2 }' >"$dir/shard.txt"
  mv "$dir/shard.txt" "$dir/scripts.txt"
  echo "shard $shard of $shards: $(wc -l <"$dir/scripts.txt" | tr -d ' ') scripts"
  if [ ! -s "$dir/scripts.txt" ]; then
    echo "nothing in this shard"
    exit 0
  fi
fi
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
