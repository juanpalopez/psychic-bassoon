---
type: lesson
date: 2026-10-16
area: balance
links: [#259]
promote: checklist
promoted-to:
---
# Keep tests on content constants, not copies of balance numbers

## What happened
Changing the board size, the foe speeds and the tower damage broke about fifteen tests that spelled out 22, 16, 2.13, 13 and 21.

## Evidence
PR #259 touched `test_foe_stats`, `test_tower_fire`, `test_tower_content`, `test_prism_beam`, `test_tower_panel`, `test_win` and the goldens.

## What we learnt
A test that repeats a balance number must change with it; some of that is deliberate (a golden or a content check), but arithmetic in other tests should read the constant.

## Rule next time
In a test, read the number from `godot/content` unless the test exists to pin it, and say so in a comment where a literal is intended.
