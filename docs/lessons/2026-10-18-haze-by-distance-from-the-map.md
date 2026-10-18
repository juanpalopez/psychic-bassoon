---
type: lesson
date: 2026-10-18
area: render
links: [#324]
promote: none
promoted-to:
---
# Fade the world past the map by its distance from the map, not by depth fog

## What happened
The diorama (#324) has to carry on past the map into haze with no edge in view. Depth fog
from the Environment was the first idea, but the camera's 20 degree field of view at a 56 to
62 degree pitch sees the ground at almost one distance, so fog cannot tell the map from the
hills behind it.

## Evidence
At the overview the screen's bottom edge meets the ground at 0.93 and its top edge at 1.12 of
the distance to the ground under the screen's middle (`sin 62 / sin 72` and `sin 62 / sin 52`).
`render/paper/haze.gdshaderinc` instead mixes `FOG` by how far a point is past the map's edge
(`haze_from` 4 to `haze_to` 30 cells), whole well before the field ends 34 cells out.

## What we learnt
A narrow, steep camera has almost no depth range, so atmospheric cues must come from where a
thing is in the world, not from how far it is from the camera.

## Rule next time
For haze, fog or fades in this game, key them on world position (distance past the map,
height), and test the edge stays out of view with `CameraRig.footprint` over every zoom and pan.
