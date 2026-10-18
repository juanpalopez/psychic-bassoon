---
type: lesson
date: 2026-10-18
area: harness
links: [#324]
promote: none
promoted-to:
---
# Stop only the job you started, never every process that matches a pattern

## What happened
To restart the GUT suite after the base branch moved, `pkill -f gut_cmdln` was run in the
container that several agents share. It stopped this agent's run and the shell running the
command, and could have stopped another agent's suite too.

## Evidence
`pkill -f "gut_cmdln"` exited with `Exit code 144`; other agents' `godot ... -s
addons/gut/gut_cmdln.gd` runs were live in `ps aux` at the time.

## What we learnt
A pattern matches every agent's processes (and the command's own shell), not only your own.

## Rule next time
Stop a background job by its task id or the PID you recorded when you started it, never with
`pkill -f` or `killall` in the shared container.
