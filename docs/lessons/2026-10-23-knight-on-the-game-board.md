---
type: decision
date: 2026-10-23
status: accepted
decided-by: owner on Claude's proposal
links: [#275, #450, #451]
---
# Start every run on the game board with the Knight, moved by a command anywhere walkable

## Context
#275 left open which hero a run takes and how it moves. The accepted hero RFC (#444, #445) asks for free movement on the cell grid; mechanic tests name their own boards and must not gain a hero that fights their foes.

## Decision
- Every run on the game board starts with the Knight of Cardboard at the Heartstone (`Game.create`, `content/heroes.gd`). Mechanic boards have no hero unless a test places one (`Heroes.place`).
- `MOVE_HERO` sends it to any walkable cell along the hero's cell path (`HeroGraph.path`). A new order replaces the walk.
- For #451: the Knight walks to foes and fights them anywhere, not only on the road. A move releases the held foe, but a foe that was fighting keeps striking while the hero is in reach. A fallen hero stands again at the Heartstone after `respawn` seconds (15 to start).
- First numbers come from the level-3 guard (320 hp, armour 4, 48 damage a second) and a speed of 1.5 cells a second, tuned later.

## Alternatives considered
- Choose a hero at the start of a run: deferred until the Camp Cook exists.
- A hero on every board, mechanic tests included: the Knight would fight their foes and change their results.

## Consequences
- Replay goldens stay unchanged until the hero fights (#451), which re-records them with the hero in the snapshot.
- A test that wants the hero on its own board calls `Heroes.place`.
