---
type: lesson
date: 2026-10-15
area: harness
links: []
promote: skill
promoted-to:
---
# Run long Godot jobs in the background and read their log file

## What happened
A full GUT run piped through `grep` in the foreground hung the tool for ten minutes, and `timeout` and long `sleep` commands are blocked.

## Evidence
A foreground `godot ... | grep` hit the 600 s limit while the same run finished in about 100 s with its output in a file.

## What we learnt
The harness waits for the whole pipe; a lingering process or buffered output looks like a hang.

## Rule next time
Start `godot --headless ... > /tmp/x.log 2>&1 &`, poll the log for `Passing Tests` or `Parse Error` in a loop of short checks, then grep the file.
