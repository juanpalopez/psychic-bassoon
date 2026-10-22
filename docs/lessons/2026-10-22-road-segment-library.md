---
type: decision
date: 2026-10-22
status: accepted
decided-by: owner on Claude's proposal
links: [#404, #406, #430]
---
# Build the valley's roads from a library of tested segment templates joined at ports

## Context
The spline roads (2026-10-21) are smooth but not good level design: each region's road is a spline through procedurally placed waypoints, so a bridge approach can twist (the owner's preview showed an awkward twist at the lower bridge), and four sections ignore the layout's road and draw their own. A mathematically smooth curve is not a designed combat space.

## Decision
- A **segment library** (`godot/content/valley/segments.gd`, data only): hand-authored, tested road pieces defined in a local frame with an entry port and an exit port (position, heading), the control points of their spline, a road width, a clearance envelope, terrain requirements and a tactical tag. First set: sweeping bend, broad S-bend, bridge crossing (straight approaches, perpendicular to the river, flat ends, no twist on the span), ridge wrap (a broad U around high ground), landmark approach (passes a ruin or the Heartkeep).
- A **fitter** places a template in a region: it picks the rotation or mirror whose entry heading matches the border the gate is on, scales it between the gate cells within curvature limits, and only joins ports whose headings and heights are compatible (a bridge needs a near straight east-west approach, so a sharp north exit is not a valid connection).
- A **composer** chooses a sequence of segments per seed and region role (Outer March: sweep or S-bend; Sunken Meadow: S-bend or sweep; Bluewater Crossing: bridge crossing; Broken Ridge: ridge wrap; Ancient Fold: landmark approach plus the feeder merge; Heartkeep: sweep or landmark approach), checks curvature, clearance, lane gap (#406), length and tower coverage, and rejects a composition and tries another. Variety comes from composition, mirroring and bounded scaling, not from free-form waypoints.
- The composed road is the single source: `slot.spine` is the fitted segment, every section follows it (no section draws its own road), and the render road bed is a ribbon swept along it with a stable local frame (no twist). The six regions, the fixed road order, the river spline and the wide band (#430) stay.
- Replaces `ValleyLayout._spine` and the sections' own waypoint code; frozen fixtures, the old strip valley and old boards are untouched until the switch ticket.

## Alternatives considered
- Keep one free-form spline per region and tune it: it produced the bridge twist and needs per-seed luck.
- Pure procedural noise or grammar for the whole route: no guarantee a bridge approach is straight or that the road is a good firing corridor.

## Consequences
- Each template is testable on its own (curvature, clearance, lane gap, ports), so a bad twist is a failing test, not a visual surprise.
- Authoring cost: the templates are hand-made; new maps and profiles come from new compositions.
- Epic #404 tickets cover the library, the fitter and composer, the sections following the road, and the ribbon; the winding river and terrain follow.
