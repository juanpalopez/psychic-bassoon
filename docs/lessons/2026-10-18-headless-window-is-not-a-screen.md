---
type: lesson
date: 2026-10-18
area: harness
links: [#328]
promote: none   # none | checklist | script | ci-check | skill | command | agent | hook | mcp | mode | plugin
promoted-to:
---
# Measure screen sizes in tests with a SubViewport, never from the headless window

## What happened
The 44 pt tap rule (#328) turns canvas pixels into points from the window's pixel size and the
screen scale. Under `godot --headless` the main scene's numbers were nonsense, so the run's start
view jumped to the closest zoom and every main-scene tap test failed.

## Evidence
A probe under `--headless`: `vis (1280.0, 1280.0) win (64, 64) scale 1.0 ds headless winsize (0, 0)`:
`get_window().size` is 64x64 while the stretched canvas is a 1280x1280 square, so 44 pt came out
as 880 canvas px (`godot/main.gd`, `tap_pixels`).

## What we learnt
The headless display has no real window: `get_window().size` is a 64x64 stub and the root canvas
is square. `DisplayServer.window_get_size()` reports (0, 0) there, which a guard can treat as
"a pixel is a point"; a real phone shape must come from the test.

## Rule next time
Read the window size from `DisplayServer.window_get_size()` with a zero guard, and run screen-shape
tests inside a `SubViewport` of the phone's canvas (1558x720 for 844x390 pt) with the points per
pixel set by the test.
