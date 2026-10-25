---
type: decision
date: 2026-10-25
status: accepted
decided-by: owner
links: [#458, #452, #550, #460]
---
# The default board is the layout valley (40 by 24, pace 0.5), with the Knight's skills, in one golden re-record

## Context
The layout valley (composed road, two lanes, regions) lived only behind `--layout-valley`. The owner approved the flip on 2026-10-25, with the Knight skills (#452) in the same re-record, so `replays.json` is written once.

## Decision
- `MapGen.game_map` asks the layout valley, then the strip valley, then the route-first map (`MapGen.first_map`); a builder that gives up logs a warning, never an error (the checked headless run fails on `ERROR:`). `Game.create` on the default arguments plays it, so `GameMap.foe_pace` 0.5 reaches the game board.
- `--strip-valley` (`Game.create_on_strip_valley`) plays the old board for one alpha; it replaces `--layout-valley`. The mechanic kits and the six `specs*.json` goldens name the strip valley and do not move.
- Knight skills: Rally Cry (towers and guards within 3 cells, +15% attack speed, guards +10% regeneration) and Blade Whirl (80 damage, 15 s cooldown).
- Only `godot/tests/goldens/replays.json` is re-recorded (`tools/write_replays_golden.gd`); the games are listed in the PR. The frozen fixtures, `terrain.json`, `sockets.json` and `socket_blocks.json` are untouched.
- Sockets on the game board: 24 to 31; map 40 by 24.

## Alternatives considered
- Two re-records (Knight skills, then the flip): the owner wants one.
- Keep the strip valley as the default until #329 and #335 land: the owner wants the map in the next alpha.

## Consequences
- The strip valley stays built and tested as the first fallback; retiring it is a later ticket.
- Revert: one list in `MapGen.game_map` plus a re-record.
- Generation costs more than the strip's (about 0.1 to 0.6 s a map, see the PR), at game start.
