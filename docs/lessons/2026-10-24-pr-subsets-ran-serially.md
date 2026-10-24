---
type: lesson
date: 2026-10-24
area: ci
links: [#473]
promote: script
promoted-to: scripts/run-gut-parallel.sh (the -t option), scripts/run-gut-parallel.test.ts
---
# Send every GUT run through the parallel runner, whatever the test selection

## What happened
A GUT speedup investigation found that pull requests with a test subset (`scripts/select-tests.mjs`, #359) ran one serial Godot process, while `main` and full runs used `scripts/run-gut-parallel.sh`. The subset path was added after the runner and never switched over.

## Evidence
`.github/workflows/ci.yml` ran `"$GODOT" ... -gtest="$GUT_TESTS" -gexit` for a subset. Runs 40031316046 and 40031372154 spent 436 s and 877 s in the GUT step, 89% to 93% of the job, on a 4 vCPU runner.

## What we learnt
Two code paths for the same job drift: the optimisation (one process per script, one worker per core) went to only one of them.

## Rule next time
When CI can run the same tool on a full list and on a subset, give both the same runner (here `run-gut-parallel.sh -t <list>`) instead of a second command line.
