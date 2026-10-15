---
type: decision
date: 2026-10-16
status: accepted
decided-by: owner
links: []
---
# Record lessons and decisions at the end of relevant tasks

## Context
Many problems recurred (commit subjects, CanvasLayer sizing, hung runs, skipped deploys) and the owner wants later runs to improve.

## Decision
Every task that decides or learns something relevant writes an entry in `docs/lessons/` from a template, lists it in its final message and its PR body; entries can be promoted into checklist lines, scripts, CI checks, skills, commands, agents, hooks, modes, MCP servers or plugins. Balance sweeps are run by a Haiku agent with a Sonnet agent helping; Opus designs and reviews.

## Alternatives considered
- A free-form notes file: nothing to promote from, grows unread.
- Memory files only: not visible to the owner or to other agents.

## Consequences
- A closing ritual in CLAUDE.md and a line in the PR template.
- Lessons marked for promotion stay open until promoted.
