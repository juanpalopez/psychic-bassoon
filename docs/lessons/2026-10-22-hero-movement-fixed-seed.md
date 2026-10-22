---
type: decision
date: 2026-10-22
status: accepted
decided-by: owner on Claude's proposal
links: [#275, #335, #444]
---
# Prototype hero movement and bridge tactics on a fixed seed of the generated valley

## Context
The RFC `docs/rfcs/2026-10-22-strategic-hero-movement-and-bridges.md` (#444) proposed a hand-authored map for the first hero prototype. `Game.create` always generates the valley, so a hand-made layout would be a second kind of map, and the generated Bluewater Crossing already has a road bridge and a hero-only bridge.

## Decision
Accept the RFC with amendments (its "Amendments" section): the prototype plays one fixed seed of the generated valley with strategic positions as content data for it; commands target any walkable cell and strategic positions are highlighted destinations; the second bridge is hero-only; the first step is the sim hero of #275. The GDD's interaction list names the strategic positions.

## Alternatives considered
- Hand-authored map: isolates the loop the same way but adds a second map path to build, test and render.
- Node-only movement: breaks the tap-anywhere contract of #275 and #335.

## Consequences
- The prototype seed must stay stable while the generator changes; its ticket pins it with a test (two crossings, positions reachable).
- Generator constraints for strategic positions wait until the prototype plays well (RFC step 6).
