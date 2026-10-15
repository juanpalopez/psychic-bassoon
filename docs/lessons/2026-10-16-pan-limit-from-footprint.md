---
type: lesson
date: 2026-10-16
area: render
links: [#266]
promote: none
promoted-to:
---
# Derive the pan limit from the ground footprint, not from a share of the board

## What happened
Pinch zoom on an iPhone drifted off the board and showed blank space that had to be realigned by hand.

## Evidence
Ticket #266; `CameraRig.pan_limit` was `0.9 * half board * zoom`; replaced by `footprint` and `pan_bounds`.

## What we learnt
A pan limit that ignores what the screen shows lets the view sit with half the screen over nothing; a pinch must also keep the point under the fingers where it was.

## Rule next time
Compute camera limits from the projected corners of the screen on the ground and test all four corners at every allowed pan.
