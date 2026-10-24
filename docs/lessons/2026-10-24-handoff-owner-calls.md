---
type: decision
date: 2026-10-24
status: accepted
decided-by: owner
links: [#469, #467, #460, #480, #481]
---
# Fix #469 with a reach of about 2.7 plus a render-side clip, and hold the other map calls

## Context
The 2026-10-23 handoff (`docs/handoff/2026-10-23-cloud-session.md`) left four calls open: road cells under the curve (#469), the Knight's balance (#467), the 3A re-gating and the slow foes' speeds.

## Decision
- #469: a mix of option 2 (raise `SOCKET_COVERAGE_REACH` to about 2.7) and option 3 (fix on the render side: clip the bed or snap the cells). Wider roads stay a goal, so swarms have more room to move.
- Knight balance (#467): keep as is (about 4 median waves added to bot runs, losses 8 to 5 of 12); revisit when the Knight is drawn and playable.
- 3A re-gating (`GATE_INSET` 2, spawn rows (1,2), cuts `LEFT_Y` 11 / `MIDDLE_Y` 8, the source of the Ridge's missing length): hold until the layout valley has grown to 40 by 24 (#480) and the fork (#481) land, then re-measure.
- Slow foes' speeds (Orc about 123 s, Golem about 167 s against the 100 s cap): decide after #460 is measured.

## Alternatives considered
- Option 2 alone: still leaves cells under the curve drawn wrongly.
- Option 3 alone: keeps the narrow reach that blocks wider roads.

## Consequences
- The reach change and the render clip need their own tickets and goldens review.
- The held items are re-measured after #480, #481 and #460.
