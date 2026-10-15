---
type: lesson
date: 2026-10-14
area: ui
links: [#252, #254, #261]
promote: checklist
promoted-to:
---
# Size a Control under a CanvasLayer from the viewport, not anchors

## What happened
The Messenger Crow, the tour overlay and the tower guide appeared in the top-left corner or off the left edge: a Control under the HUD CanvasLayer got a size of 0 or its content minimum, so full-rect anchors did nothing.

## Evidence
Screenshots in PRs #252, #254, #261; fixes use `get_viewport_rect().size` (`ui/messenger_crow.gd`, `ui/intro_view.gd`, `ui/guide_panel.gd`).

## What we learnt
Anchors resolve against a parent Control; a CanvasLayer is not one. Nodes made in code under it must set their own position and size and re-fit on `size_changed`.

## Rule next time
For any overlay or code-made Control under a CanvasLayer, set position and size from the viewport rect, test it with a size of 0, and look at a screenshot before opening the PR.
