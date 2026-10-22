---
type: rfc
date: 2026-10-22
status: accepted
links: [#275, #335, #404, #432]
---
# RFC: strategic hero movement and bridge tactics

## Status and decision sought

**Status:** Accepted with amendments (owner, 2026-10-22; `docs/lessons/2026-10-22-hero-movement-fixed-seed.md`). The amendments below win over the sections they name.

### Amendments (owner, 2026-10-22)

1. **A fixed seed, not a hand-authored map** (replaces the hand-authored map in sections 9, 12 and 13). `Game.create` always generates the valley, so a hand-made layout would be a second kind of map. The prototype plays one fixed seed of the generated valley, chosen in its ticket for two usable crossings, with the strategic positions as content data for that seed. It isolates the movement loop from the generator just as well, and the generator constraints of step 6 still come only after it works.
2. **Open question 1 is settled: both.** A command targets any walkable cell (the contract of #275 and #335); strategic positions are highlighted, named destinations on top.
3. **Open question 4 is settled: the second bridge is hero-only.** The generated Bluewater Crossing already builds one road bridge and one hero-only bridge at least `HERO_BRIDGE_MIN_ROW_GAP` (4) rows apart (`GameMap.hero_bridges`), so the road keeps its single river crossing.
4. **Open question 5 is answered** (code on `main`, 2026-10-22): the sim has walkable cells and `HeroGraph` (`godot/sim/map/valley/hero_graph.gd`, #385), a 4-neighbour flood fill with `travel_steps`, used today only as a map check. There is no hero unit, move command, path following, arrival or failure state yet (#275), and no bridge-specific guard rule (the guard post is #323). Step 1 of section 12 is therefore done, and the first implementation step is #275.
5. **Decide the path shape in #275:** `HeroGraph` counts cell steps while foes walk curved routes. #275 chooses whether the hero walks cell to cell or a smoothed path, because the travel-time test of section 11 depends on it.
6. Open questions 2 and 3 (standing on the span, what ends a bridge lock) stay open for the prototype; the hero has hp and blocks like a guard (#275), so a lock lasts only while it lives.

This RFC proposes a tactical movement layer for *Kingdom of the Fold*: a hero supports tower coverage by moving between strategically meaningful places, while bridges create consequential choices about where to defend. It does not implement the system.

The requested decision is whether to adopt the hybrid movement model and the prototype scope below before implementation work begins.

## Summary

Keep the game's core loop as tower defense with light RTS tactics—not a full RTS. Towers provide persistent coverage; one player-controlled hero supplies mobile intervention. Bridges are both terrain crossings and potential tactical chokepoints.

Use two related but separate route models:

- **Enemy route:** the existing composed road spine, used for enemy movement and road-dependent map checks.
- **Hero navigation:** a traversability-aware movement system for the hero, with a small set of authored strategic positions layered on top.

Strategic positions give the player legible destinations and give the map designer a way to validate important tactical connections. They should not force every hero command to target a node: the GDD already describes issuing movement commands to walkable terrain. Preserve that freedom for the initial hybrid unless playtesting demonstrates that node-only movement is better.

Start with one hand-authored valley and two bridges. Do not couple the first playable prototype to procedural road composition.

## 1. Motivation

The current road segment library is a useful way to improve enemy-route composition, but road geometry alone cannot express the hero's tactical choices. A bridge needs a clear approach, safe landing space, and a reason to defend it; the hero also needs a way to move between fronts without following the enemy road exactly.

The existing GDD describes a 32 × 20 logical grid, a continuous primary enemy route, a later feeder, river crossings at authored bridges, and walkable ground that excludes water and tall cliffs. It also calls for multiple walkable connections between important regions. Issue #275's update records the intended RTS-like direction: the hero can move to walkable terrain rather than only along the road.

This RFC adds a strategic-position layer to that direction. It does not claim that the full hero navigation system or all the proposed bridge mechanics are already implemented.

## 2. Goals

- Make hero repositioning a meaningful time-and-risk decision.
- Make at least two bridge crossings tactically distinct.
- Keep the enemy road independent of hero navigation.
- Preserve a readable, touch-friendly tower-defense experience.
- Validate the gameplay on a small authored map before adding procedural complexity.
- Keep the design deterministic and testable where it touches simulation or procedural generation.
- Leave the current road segment library focused on enemy-road geometry.

## 3. Non-goals

- A full RTS economy, worker system, army command, or multiplayer.
- Destructible bridges, dynamic river simulation, or complex bridge repair in the first prototype.
- Replacing the enemy road with a branching maze.
- Reworking the entire map generator as part of the RFC implementation.
- Adding road templates solely to meet a target count.
- Making every strategic location a mandatory hero movement waypoint.

## 4. Verified baseline and current design

Repository references inspected for this proposal:

- `docs/GDD.md`: the current design baseline describes the tower-defense loop, movable hero, walkable terrain, river and bridges, and the 32 × 20 grid.
- `godot/content/valley/segments.gd`: defines five road templates: `SWEEP`, `S_BEND`, `BRIDGE`, `RIDGE_WRAP`, and `LANDMARK`.
- `godot/sim/map/valley/segment_fitter.gd`: fits a road template between region gates and checks bounds and smoothness.
- `godot/sim/map/valley/route_composer.gd`: composes region spines from allowed templates and rejects invalid compositions.
- `godot/sim/map/valley/valley_layout.gd`: defines the six-region valley, river cells, bridge crossing constraints, and road-layout validation.
- `docs/lessons/2026-10-22-road-segment-library.md`: accepted decision for a tested, port-connected road segment library and a single composed road source.

These files establish an enemy-road composition system. They do not by themselves establish that hero navigation already uses a strategic graph, or that bridge upgrades and bridge-specific combat rules exist. Verify hero movement code and tests again when implementation begins.

### Existing design constraint to reconcile

The GDD and issue #275 describe click-to-move to valid walkable terrain. This RFC recommends a **hybrid**: retain valid world-space movement commands, while exposing strategic positions as named, highlighted, and testable destinations. A graph can model strategic connectivity and validate the map without becoming the only way to issue a command.

If the owner instead wants strictly node-to-node movement, that is a player-control change and should be decided explicitly rather than slipping in as an implementation detail.

## 5. Proposed player experience

The player builds towers and prepares for a wave, reads which front is under pressure, and sends the hero to a bridge, ridge, crossroads, ruin, or final defensive line. The hero takes measurable time to travel. Towers continue to cover their own lanes while the hero is away.

A representative choice:

1. A fast enemy threatens the West Bridge early in the route.
2. A second group is approaching the East Bridge, closer to the Heartkeep.
3. The hero can intercept the early group, reposition to the later crossing, or stay near the objective.
4. Each choice has a cost: travel time, reduced support elsewhere, or damage that towers must absorb.
5. A poor choice should be recoverable through tower coverage, abilities, and later repositioning—not an automatic loss.

The game should communicate destination, route, estimated travel time, and arrival clearly. Avoid requiring high-frequency micromanagement.

## 6. Strategic positions and navigation

### Position types

For the first authored valley, provide a small, purposeful set of positions:

- West Bridge approach / hold.
- East Bridge approach / hold.
- Central crossroads.
- Ridge firing position.
- Ruin or fallback position.
- Heartkeep defensive position.
- Optional tower-support position where the terrain gives it a distinct purpose.

These are semantic anchors, not necessarily discrete tiles. Each should have a stable ID, a world-space location, a role, and interaction metadata where needed. Avoid duplicating nodes for locations that do not create a distinct choice.

### Connectivity model

Represent authored strategic connectivity as a graph (G=(V,E)):

- A vertex identifies a strategic position.
- An edge represents a valid hero traversal between two positions.
- Edges may be directed if terrain or an interaction genuinely makes travel asymmetric; otherwise use undirected connections.
- Edge metadata may include traversal type, bridge ID, movement cost, and whether the edge is currently available.
- Travel cost should ultimately be derived from the actual traversable path and hero movement speed, not a hand-entered seconds value that can drift from gameplay.

For the first prototype, use the existing walkability and deterministic cell-grid pathfinding if available. The strategic graph is a high-level layer for destination presentation, connectivity validation, and tactical metadata—not a second, conflicting source of truth for collision or walkability. If code inspection finds no reusable pathfinder, document that gap and add the smallest tested pathfinding seam in a separate implementation PR.

Do not add an arbitrary graph framework or a general-purpose navigation service without a demonstrated need.

### Movement states

The implementation should define observable outcomes for at least:

- Idle / holding position.
- Moving toward a requested destination.
- Arrived.
- Destination unreachable.
- Movement interrupted or route invalidated.

A new command should replace the current destination cleanly. Arrival and failure must be deterministic and testable. The hero must not move through water or tall cliffs; bridges and explicitly authored transitions are the only connections across those barriers.

## 7. Bridges as tactical features

Bridges should be visually obvious and have usable approach and landing space on both banks. A bridge can connect the hero navigation layer and carry the enemy road, but these are separate relationships: a hero traversal edge must not be inferred solely because an enemy road segment has the `BRIDGE` tag.

For the initial prototype:

- Use two permanent crossings with different strategic roles.
- Give each crossing a named position on each approach, or a clearly defined hold position if the map supports it.
- Make the bridge and approach traversable only where the map says they are walkable.
- Let narrow geometry create a readable enemy chokepoint; test hero blocking and combat interactions against current guard rules.
- Show when the hero is committed to a crossing and how long a reposition is expected to take.
- Preserve alternative defensive options so bridges are valuable but not the only viable strategy.

Defer bridge destruction, repair, barricades, traps, and changing enemy routes. Consider these only after the basic repositioning loop proves fun.

## 8. Relationship to enemy roads and map generation

Keep the composed enemy road as the source of truth for enemy movement and road rendering. Do not make enemy movement depend on the hero graph. Do not have each terrain section invent its own enemy route.

The current road library's templates are not all distinct geometries: the sweep, ridge wrap, and landmark approach share a similar quarter-turn silhouette. That is a valid separate road-library concern, but it should not be solved by conflating geometry with bridge or navigation semantics.

Recommended separation:

1. **Road geometry:** sweep, true S-curve, hairpin, diagonal, straight, and other shapes when justified by a visible route need.
2. **Terrain features:** river, bridge, ridge, cliff, ruin, and walkability constraints.
3. **Tactical positions:** hero destinations, hold areas, and important connections.
4. **Composition rules:** place road and terrain features so the map preserves both enemy-route validity and hero tactical choices.

Do not immediately add a larger segment library. First prove the hero's movement decisions on an authored layout. During later procedural integration, each generated map must validate both the enemy road and the hero navigation graph. A valid road is not sufficient if it leaves a bridge unreachable or disconnects a required strategic position.

## 9. Prototype map

Build a single hand-authored Broken Valley test layout with:

- A river dividing the play space.
- Two permanent bridges at different distances from the Heartkeep.
- One continuous enemy route with a crossing at each intended bridge only if supported by the map layout; otherwise use a single main-road crossing and make the second bridge hero-only.
- A crossroads, ridge, ruin, and Heartkeep position.
- Several existing tower sites and enough walkable space to reach both crossings.
- A wave that threatens the two defensive fronts at different times.

The exact topology must be checked against the current map and road constraints. Do not add a second enemy-road crossing to the existing generated valley without validating the current river rules, which presently require the crossing region's road to cross the river in one stretch.

Use debug overlays for node IDs, graph edges, walkable cells, blocked terrain, chosen hero path, and estimated travel time. Keep these tools out of the shipped visual layer unless they become useful player-facing feedback.

## 10. Architecture proposal

Prefer small data structures compatible with the current Godot project:

- `StrategicPosition`: stable ID, world location, role, optional interaction/feature ID.
- `StrategicConnection`: endpoints, traversal type, optional bridge/transition ID, availability predicate or state.
- `HeroNavigation`: a thin adapter over the existing walkability/pathfinding implementation; resolves movement requests and returns a path or a failure reason.
- `StrategicMap`: authored position and connection data plus validation; it should not own enemy road composition.

These are conceptual responsibilities, not names that must become classes. Follow existing naming, data, and testing conventions after inspecting the hero and map code. Avoid adding duplicate representations of walkability or path costs.

Bridge availability should affect only the relevant traversal connection and low-level walkability data. If a connection becomes unavailable while the hero is using it, the implementation must either safely finish the crossing or stop and request a new path; choose and test one policy before adding dynamic bridge states.

## 11. Testing and validation

### Unit tests

- Reject duplicate or missing strategic-position IDs.
- Reject connections whose endpoints do not exist.
- Reject a bridge connection that does not join the intended banks or uses non-walkable endpoints.
- Validate graph connectivity for all positions required by the authored map.
- Validate that blocked water and cliffs cannot be crossed without an authored connection.
- Verify path results and unreachable outcomes for representative small grids.
- Verify movement commands replace previous destinations and produce arrival/interruption states.

### Integration tests

- The hero can move between both bridge approaches, the crossroads, ridge, ruin, and Heartkeep.
- Travel time follows the actual route length and configured hero speed within a defined tolerance.
- Closing or blocking a connection never produces a path through invalid terrain; an alternative is selected when one exists.
- Enemy routes and their determinism are unchanged by hero graph operations.
- Bridge approaches remain usable and have room for intended combat interactions.
- Existing map and segment tests continue to pass.

### Gameplay validation

Run a repeatable wave scenario that pressures both bridges. Record hero travel time, how long the unguarded front is exposed, whether towers can cover the abandoned front, and whether the player has a reasonable recovery option. Use playtesting to tune the timing; do not encode the illustrative values from a design discussion as balance constants.

## 12. Incremental implementation plan

1. **Audit hero movement:** verify the actual implementation, walkability source, deterministic pathfinding, movement command, and tests. Record gaps.
2. **Author the prototype map:** mark the two crossings and tactical positions on a fixed seed or hand-authored map; add debug visualization.
3. **Add strategic metadata:** define positions and connections using existing data conventions and validate IDs/connectivity.
4. **Connect movement commands:** preserve valid click-to-move, highlight strategic destinations, show path and travel-time feedback, and test unreachable states.
5. **Tune the bridge scenario:** create a wave that pressures both fronts; playtest whether repositioning creates a meaningful choice.
6. **Integrate with procedural generation:** only after the authored scenario works, add graph constraints to map validation and retry logic.
7. **Revisit road geometry:** improve or add templates only for demonstrated geometric gaps; preserve bridge alignment, curvature, clearance, lane separation, and port compatibility.

Each stage should be a focused PR with tests. Keep this RFC documentation-only.

## 13. Acceptance criteria for the first implementation

- A hand-authored map contains two usable crossings with distinct tactical roles.
- The hero can be commanded to strategic positions and valid walkable destinations without being constrained to the enemy road.
- Invalid terrain remains impassable.
- The player can see the hero's requested destination and receive clear feedback on arrival or failure.
- Travel time is measurable and creates a meaningful cost to switching fronts.
- A wave scenario demonstrates at least one non-trivial choice between bridge defence and objective defence.
- The hero graph does not change enemy routing or road-generation determinism.
- Automated tests cover connectivity, blocked terrain, crossing constraints, and movement outcomes.
- The prototype is playtested before the graph is integrated with procedural generation.

## 14. Alternatives considered

### Free movement only, with no strategic layer

Simple and consistent with click-to-move, but it provides no explicit representation for important tactical destinations, bridge validation, or map-composition guarantees. Retain free movement as a command capability, but add strategic metadata.

### Strict node-to-node movement

Easy to reason about and balance, but it removes some of the freedom described in the current GDD and risks making the hero feel like a token on a board. Do not adopt it without an explicit control-design decision and prototype comparison.

### One graph for enemies and hero

Rejected. Enemy movement follows the composed road, while hero movement must traverse walkable terrain and may use paths that are not part of the enemy route. Sharing a single graph would couple unrelated gameplay constraints.

### Procedural generation first

Rejected. It would make it harder to tell whether poor decisions come from the movement model, tactical layout, or generator. Validate the loop on an authored map first.

### More road templates first

Deferred. The current templates have overlapping silhouettes, but template count is not the core problem. Add geometry only when it creates a visible and useful route distinction.

## 15. Risks and mitigations

- **Hero feels slow or unresponsive:** show path and travel-time feedback; tune movement after playtesting.
- **Bridges dominate every decision:** provide viable tower coverage and alternate positions; do not make both crossings mandatory kill zones.
- **Graph and walkability disagree:** keep the low-level traversability source authoritative and validate graph edges against it.
- **Procedural maps become too constrained:** keep the authored prototype separate; add generator constraints only after the loop is proven.
- **Scope expands into an RTS:** keep one hero, wave-based defence, existing tower systems, and no army/economy simulation.
- **Current design docs conflict:** update the GDD only after the owner accepts the control model; do not silently replace the current click-to-move contract.

## 16. Open questions

1. Should a hero command target any walkable point, a strategic position, or both? This RFC recommends both.
2. Can the hero stand on the bridge span itself, or should hold positions be limited to its approaches?
3. Should the hero block enemies on bridges under the existing guard rules, and what prevents a permanent bridge lock?
4. Does the second bridge carry the enemy route, or is it a hero-only traversal route in the first scenario?
5. Which hero movement and interruption behaviours already exist in code and can be reused?

Resolve these through code inspection and a small playable prototype, not speculative abstractions.

## References

- [Game Design Document](../GDD.md)
- [Road segment library decision](../lessons/2026-10-22-road-segment-library.md)
- [Hero implementation issue #275](https://github.com/juanpalopez/psychic-bassoon/issues/275)
- [Road composition epic #404](https://github.com/juanpalopez/psychic-bassoon/issues/404)
- [Road segment library issue #432](https://github.com/juanpalopez/psychic-bassoon/issues/432)
