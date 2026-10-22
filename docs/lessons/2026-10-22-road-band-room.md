---
type: lesson
date: 2026-10-22
area: sim
links: [#430, #404]
promote: none
promoted-to:
---
# Measure the room a wider road takes before fixing a clearance in a ticket

## What happened
#430 asked for a 2.4 cell road band with 1 cell between it and every socket block. Sweeping
the clearance showed the layout valley cannot hold it: the regions are 9 to 12 cells wide.

## Evidence
Seeds 1 to 20, first draws: clearance 1.0 left 254 of the 469 blocks the old road gets;
0.25 failed to stitch on 10 of 60 seeds (`valley layout seed 19: no draw passes its checks`);
0.0 stitches all 60. A block's centre is then 2.2 cells from the curve, and the shortest
tower range is 2.3 (`godot/content/towers.gd`), so level 1 towers barely reach the centre line.

## What we learnt
Rules written for the one-cell road (touch distance 1.6, cover 2.3) are cell-based and cannot
carry a band; a check that runs while a section is drawn must see the same `road_curve` as the
final check (the Ridge set it after placing, so 37% of first draws failed).

## Rule next time
Sweep a new clearance or width against the stitcher (fail count and time per seed) before
writing its number into a ticket, and set `road_curve` before placing sockets.
