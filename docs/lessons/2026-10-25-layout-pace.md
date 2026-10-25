---
type: decision
date: 2026-10-25
status: accepted
decided-by: owner
links: [#460, #458]
---
# Foes walk the layout valley at half their content speed (FOE_PACE 0.5)

## Context
The layout road is 77 to 86 cells (median 82) against the strip valley's 150, so at pace 1.0 foes spend 0.46 (main road) and 0.49 (lower lane) of the strip's time under fire (63.9 s median, band edge at 2.0 cells). Owner: one factor for every foe, no road growth.

## Decision
`LAYOUT.FOE_PACE` is 0.5. `measure_road_time --speed=` over seeds 1..300 (time scales as 1/f): 0.50 gives 0.910 / 0.978; 0.55 gives 0.83 / 0.89; 0.60, 0.65, 0.70 give 0.76 / 0.81, 0.70 / 0.75, 0.65 / 0.70. 0.50 and 0.45 (about 1.01 / 1.09, not swept) are inside 0.90 to 1.10 on both lanes; the owner chose 0.5, the round factor in the band.
Bot sweep, seeds 1..8, five profiles, 40 games: games not lost in 20 waves strip 22, layout 0.50 25, 0.55 23, 1.0 2. Mean Heartstone health about 6.3 (strip), 9.0 (0.50), 7.4 (0.55). Wins at wave 20: strip 8, 0.50 4, 0.55 4, 1.0 2. The bot survives as often as on the strip valley but clears the last wave less.

## Alternatives considered
- The March hook (+12 cells): only 61% of seeds fit it, and generation cost 2.4 times (721 to 1,720 ms on seeds 1..40 under the same load; hook draws failed the stitch 86% of the time against 57%). Dropped.
- 0.55 and slower: ratios under 0.90.

## Consequences
- Walk times at 0.5: Scrap Goblin about 100 s. Slow foes follow (Orc, Golem); the brute cap is a later tempo ticket.
- Fewer wave-20 clears (4 against 8 of 40, not significant); "no worse than strip" covers survival and Heartstone health only. Tempo is a later ticket.
- The default board is still the strip valley, so no golden or fixture moves; #458 re-records goldens on the switch.
