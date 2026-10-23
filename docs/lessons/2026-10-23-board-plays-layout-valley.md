---
type: decision
date: 2026-10-23
status: accepted
decided-by: owner
links: [#458, #457, #404]
---
# Play the layout valley with the composed road on the game board

## Context
The composed road (#436, #438, #439) and the regions that follow it (#434) lived only in the layout
valley, which only the preview tools drew; the game still played the strip valley. The owner wants
the new map in the next alpha (2026-10-23). Over seeds 1 to 200 every layout seed builds (23 to 29
sockets, the strip valley gives 21 to 28), at about 0.1 s a map against 0.035 s for the strips.

## Decision
`MapGen.game_map` builds the layout valley (`MapGen.generate_layout_valley`: `ValleyLayout.generate`
then `ValleyStitcher.build` with `ValleyLayout.sections()`), falls back to the strip valley
(`generate_valley`), then to the route-first map, and warns at each fallback (`MapGen.first_map`).
Every replay on the game board starts from the new map, so `tests/goldens/replays.json` is
re-recorded with `tools/write_replays_golden.gd`; `terrain.json` reads the route-first map and is
unchanged; the frozen fixtures are untouched. CLAUDE.md (Architecture) carries the rule.

## Alternatives considered
- Keep the strip valley until every region ticket lands: the owner wants the new map in this alpha.
- Drop the strip fallback: no seed needs it today, but it costs nothing and keeps a run playable.

## Consequences
- The strip valley stays built and tested (`generate_valley`) as the first fallback; removing it is
  a later ticket once the layout has held for a release.
- Reverting is one line in `MapGen.game_map` plus re-recording `replays.json`.
