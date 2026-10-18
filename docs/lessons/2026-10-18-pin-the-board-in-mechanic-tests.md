---
type: lesson
date: 2026-10-18
area: sim
links: [#320, #259]
promote: checklist
promoted-to: docs/REVIEW-CHECKLIST.md (What to check, 4. Tests)
---
# Give a mechanic test the board it was written on

## What happened
Moving the game to the 32x20 valley broke eleven tests outside the goldens. Four were about a mechanic (two moth rankings, a bomb on a flyer, a blast beside a leak) but used `Game.create(seed)` and leaned on that seed's 16x11 map: a socket near the road's end, a short air line.

## Evidence
`test_razor_moth.gd:139` `[31.85] expected to be < than [29.5]`; `test_hit_hold.gd:105` `[850.0] expected to be < than [850.0]: the blast went off beside it`; `test_aviary_spec.gd:182`. A repeat of `2026-10-16-tests-on-content-constants.md` (#259 broke about fifteen tests the same way).

## What we learnt
The default board is a balance choice that moves; a test that needs a geometry must say which.

## Rule next time
A test about a mechanic builds its game on a named board (`TowerFireKit.landscape(seed)`, or `Game.create(seed, cols, rows)`), and only a test about the game board uses the default.
