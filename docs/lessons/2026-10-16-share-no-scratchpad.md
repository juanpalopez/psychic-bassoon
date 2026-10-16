---
type: lesson
date: 2026-10-16
area: harness
links: []
promote: script
promoted-to: scripts/balance_wins.py, scripts/run-gut.sh
---
# Keep reusable tools in the repo, not in the shared scratchpad

## What happened
After a Haiku agent finished, the session scratchpad held only its own folder: our Python venv with gdformat, the sweep reader, the probes and the screenshot scripts were gone, and gdlint and gdformat could not run until the venv was rebuilt.

## Evidence
`ls scratchpad` showed only `graphify-trial`; `gdformat not found`; rebuilt with `python3 -m venv ... && pip install gdtoolkit==4.5.0`.

## What we learnt
Subagents share the session scratchpad and a task that says to clean up after itself can clear the parent. Anything we reuse (a results reader, the test runner) belongs in `scripts/`, tracked and reviewed.

## Rule next time
Give each subagent its own subdirectory of the scratchpad and say never to delete outside it; keep reusable helpers in `scripts/` (`balance_wins.py`, `run-gut.sh`) and rebuild the lint venv with `gdtoolkit==4.5.0`.
