# Balance

The numbers of the sim (foes, towers, economy) started from the 2D prototype's, whose road was short (a 9 by 13 board). This file records what headless runs of the scripted bot say about them, so a change to a number can be judged by its effect and not by feel. The owner tunes; Claude proposes and measures.

## How to run it

```bash
godot --headless --path godot -s tools/balance_run.gd -- --seeds=1,2,3,4,5,6,7,8 --waves=20 --detail
```

How to explore without spending a full sweep: change one thing at a time, play one profile on six seeds (`BALANCE_PROFILES=guardMix python3 scripts/balance_sweep.py '<configs>' 1,2,3,4,5,6`), and run all profiles on seeds 1 to 16 only for the numbers that go into this file. Each sweep config is its own copy of the project, so compare a few configs at once rather than one by one.

Options: `--seeds=` (comma-separated map seeds), `--profiles=` (`spoolOnly`, `mortarHeavy`, `prismHeavy`, `mix`; see `godot/content/bot_profiles.gd`) and `--waves=` (waves to clear, 1 to 20; the run also stops when the Heartstone falls, when wave 20 is cleared and the run is won, or after 30 minutes of play). `--detail` adds the wave tables below. Twenty-four runs of about 20 minutes of play each take about a minute.

The bot (`godot/sim/bot`) builds its profile's towers in turn on the sockets that reach the most road, saves up when it cannot pay, upgrades (lowest level, then cheapest) once every socket has a tower, and launches the next wave as soon as none is running. It is a steady, mildly clever player, not an expert: it never sells, never calls a wave early (in these profiles), and builds in a fixed order. A human who plays well should do better; a human who plays badly, worse.

## Baseline (the numbers inherited from the prototype, on the 22 by 16 board with one road)

Measured on `main` after Map v2 (one road, 2x2 sockets) and the combat core, with the prototype's tower, foe and wave numbers unchanged. Seeds 1 to 8, 20 waves.

```
profile        seed  cleared  died  heart  sockets  towers  levels(0/1/2)  buttons  kills  leaks  minutes
spoolOnly         1        9    10      0       20      20  15/5/0          6    129     10     10.8
spoolOnly         2       20     0     14       18      18  0/0/18       1171    417      1     17.8
spoolOnly         3       20     0     14       17      17  0/0/17       1483    417      1     25.1
spoolOnly         4       20     0     14       19      19  0/0/19        745    417      1     20.6
spoolOnly         5        7     8      0       14      14  13/1/0         40     88     10      6.3
spoolOnly         6       20     0     20       17      17  0/0/17       1770    418      0     16.8
spoolOnly         7       20     0     12       14      14  0/0/14       1992    416      2     23.3
spoolOnly         8       20     0     20       15      15  0/0/15       1874    418      0     19.2
spoolOnly      median waves cleared: 20

spoolOnly, waves averaged over the runs that cleared them
wave  runs  clear(s)  kills  leaks  towers  buttons
   1     8      18.5    7.0   0.00     4.0       25
   2     8      18.4    9.0   0.00     5.0       30
   3     8      17.9   10.0   0.00     6.0       41
   4     8      69.8   11.9   0.12     7.8       58
   5     8      17.4   13.0   0.00     9.6       55
   6     8      78.5   14.0   0.00    12.0       78
   7     8      74.1   15.2   0.75    14.9       60
   8     7      79.6   16.7   0.29    16.9       79
   9     7      76.9   18.0   1.00    17.1       69
  10     6     151.8   21.3   0.67    16.7      134
  11     6      67.3   21.0   0.00    16.7       69
  12     6      62.5   23.0   0.00    16.7       96
  13     6      66.6   24.0   0.00    16.7      124
  14     6      58.5   26.0   0.00    16.7      120
  15     6      19.3   27.0   0.00    16.7      107
  16     6      62.3   28.0   0.00    16.7      124
  17     6      56.8   30.0   0.00    16.7      176
  18     6      57.8   31.0   0.00    16.7      382
  19     6      72.0   33.0   0.00    16.7      790
  20     6     113.5   36.0   0.00    16.7     1506
mortarHeavy       1       20     0     14       20      20  0/7/13        252    417      1     18.3
mortarHeavy       2       20     0     14       18      18  0/4/14        371    417      1     15.9
mortarHeavy       3       20     0     14       17      17  0/2/15        363    417      1     20.9
mortarHeavy       4       20     0     14       19      19  0/7/12        305    417      1     19.0
mortarHeavy       5       20     0      8       14      14  0/0/14        945    414      4     16.7
mortarHeavy       6       20     0     14       17      17  0/1/16        340    417      1     15.4
mortarHeavy       7       20     0     14       14      14  0/0/14        808    417      1     20.3
mortarHeavy       8       20     0     14       15      15  0/0/15        524    417      1     17.9
mortarHeavy    median waves cleared: 20

mortarHeavy, waves averaged over the runs that cleared them
wave  runs  clear(s)  kills  leaks  towers  buttons
   1     8      22.3    7.0   0.00     2.0       45
   2     8      24.3    9.0   0.00     3.0       50
   3     8      25.5   10.0   0.00     3.0      111
   4     8      64.1   12.0   0.00     4.5       83
   5     8      16.9   13.0   0.00     6.0       78
   6     8      62.0   14.0   0.00     7.4       96
   7     8      57.2   15.8   0.25     9.6       83
   8     8      62.1   16.9   0.12    11.8       91
   9     8      67.7   19.0   0.00    14.4       90
  10     8     146.8   21.0   1.00    16.0       78
  11     8      66.2   21.0   0.00    16.8       94
  12     8      58.7   23.0   0.00    16.8      102
  13     8      56.4   24.0   0.00    16.8       88
  14     8      53.8   26.0   0.00    16.8       92
  15     8      13.4   27.0   0.00    16.8      104
  16     8      52.8   28.0   0.00    16.8      124
  17     8      47.0   30.0   0.00    16.8      154
  18     8      44.0   31.0   0.00    16.8      127
  19     8      45.3   33.0   0.00    16.8      172
  20     8      95.5   36.0   0.00    16.8      488
mix               1       20     0     10       20      20  0/6/14        390    415      3     22.0
mix               2       20     0     14       18      18  0/2/16        251    417      1     18.4
mix               3       20     0     14       17      17  0/0/17        323    417      1     27.5
mix               4       20     0     14       19      19  0/6/13        355    417      1     21.8
mix               5        8     9      0       14      13  13/0/0         18    106     10      7.8
mix               6       20     0     14       17      17  0/0/17        460    417      1     18.5
mix               7       20     0     14       14      14  0/0/14       1018    417      1     25.3
mix               8       20     0     14       15      15  0/0/15        564    417      1     18.6
mix            median waves cleared: 20

mix, waves averaged over the runs that cleared them
wave  runs  clear(s)  kills  leaks  towers  buttons
   1     8      22.5    7.0   0.00     2.0       85
   2     8      25.9    9.0   0.00     3.0       30
   3     8      27.5   10.0   0.00     4.0       41
   4     8      78.9   11.9   0.12     5.0       96
   5     8      21.3   13.0   0.00     6.0       96
   6     8      72.8   13.8   0.25     8.0       74
   7     8      68.3   15.5   0.50     9.9       90
   8     8      74.8   16.5   0.50    12.4       71
   9     7      84.9   19.0   0.00    14.7       76
  10     7     152.7   21.0   1.00    16.6       66
  11     7      82.7   21.0   0.00    17.1       88
  12     7      71.2   23.0   0.00    17.1      109
  13     7      70.7   24.0   0.00    17.1      127
  14     7      69.7   26.0   0.00    17.1      134
  15     7      18.4   27.0   0.00    17.1      109
  16     7      69.6   28.0   0.00    17.1      101
  17     7      63.1   30.0   0.00    17.1      141
  18     7      59.5   31.0   0.00    17.1      173
  19     7      59.9   33.0   0.00    17.1      203
  20     7     109.3   36.0   0.00    17.1      480

mean main road over 8 seeds: 71.1 cells (the old 9 by 13 board: 33.1)

wave composition on seed 1
wave  foes  goblins  orcs  golems  total hp  first foe in (s)  last foe in (s)
   1     7        7     0       0       140               0.2              4.1
   2     9        9     0       0       216               0.2              5.1
   3    10       10     0       0       290               0.2              5.5
   4    12       10     2       0       798               0.2              7.7
   5    13       13     0       0       520               0.2              5.0
   6    14        8     6       0      2212               0.2             10.8
   7    16       11     5       0      2354               0.2             10.7
   8    17       12     5       0      2749               0.2             10.8
   9    19       10     9       0      4786               0.2             13.7
  10    22       14     7       1      8027               0.2             14.4
  11    21       16     5       0      4268               0.2             11.4
  12    23       19     4       0      4406               0.2             11.2
  13    24       14    10       0      8552               0.2             14.2
  14    26       20     6       0      7036               0.2             12.4
  15    27       27     0       0      3537               0.2              7.2
  16    28       15    13       0     14235               0.2             15.2
  17    30       22     8       0     11528               0.2             13.0
  18    31       22     9       0     13600               0.2             13.1
  19    33       20    13       0     19104               0.2             14.5
  20    36       16    19       1     35867               0.2             17.8
```

## What the baseline says

- **The game is far too easy after the first boss.** The bot clears 20 waves on 21 of the 24 runs. It builds a tower on every socket (the `sockets` and `towers` columns match on every run but one lost run, which was one tower short) and ends with most towers at level 3. It still holds unspent Buttons: 700 to 2,000 for the Spool Guard strategy, about 250 to 1,020 for the other two, which finish with some towers at level 2. The economy runs out of things to buy.
- **The first boss is the only real test.** Wave 10 (the Cardboard Golem and an escort) leaks on most runs (the Golem costs 6 Heartstone health when it gets through). The three lost runs (Spool Guards only on seeds 1 and 5, the mix on seed 5) die on waves 8 to 10, with only 13 to 20 towers built and almost none upgraded: the bot was behind on Buttons, not out-fought late. (At the time of this baseline the Golem did not split yet; see the next section.)
- **Waves 1 to 3 are safe, waves 4 to 9 leak a little**, which matches the target for the early game.
- **The long road helps the player.** The main road is about 71 cells on the 22 by 16 board against about 33 on the old 9 by 13 one (the `mean main road` line of the `--detail` output, over seeds 1 to 8), so the same tower numbers get more than twice the time on target.
- **Strategies hardly differ.** Spool Guards alone, Mortar-heavy and the mix all clear the same waves, so the Orc counter and the swarm counter do not matter yet.

## Sweeping several sets of numbers

```bash
python3 scripts/balance_sweep.py '[{"waves:HP_QUADRATIC": 0.03}, {"waves:HP_QUADRATIC": 0.05}]'
```

Each item of the list is one configuration: `"file:CONSTANT": value` sets a `const` of `godot/content/<file>.gd` (`waves`, `foes`, `towers` or `rules`), and `"sub:file#n": ["old text", "new text"]` replaces a piece of text (for a number inside a table, such as a tower's damage list). The optional second and third arguments are the seeds (default `1,...,8`) and the number of parallel workers. The script never touches the working tree: it copies the project, edits the copy and prints, per configuration and profile, the waves each seed cleared, the waves they died on, the mean Buttons left and the mean Heartstone health.

## Limits of the bot

- It saves up for its next tower and upgrades nothing until every socket has a tower, which is why the lost runs show almost no upgrades: they were still building when the waves caught up.
- The per-wave rows count kills and leaks since the previous clear. A game that ends in the middle of a wave keeps those numbers in `unfinished`, and with early calls kills belong to the wave that clears next.
- It never sells, never moves a tower and plays one fixed build order per profile.

## Sockets next to the road (2026-10-12)

**The baseline tables and bullets above were measured under the first block-socket rule and no longer describe the game.** That rule accepted a 2x2 block when any one cell was within 2 cells of the road. Over 60 maps and 1,047 sockets, 291 (28%) reached no road cell with a level 1 Spool Guard and 314 (30%) were farther than 2.3 cells from the road.

A block is now accepted only when it touches the road and has a stretch of it to shoot at: a road cell's centre within 1.6 cells of the block's centre, and at least 3 road cells within 2.3 cells of it (a level 1 Spool Guard's reach). A block's centre sits on a cell corner, so the nearest a road cell can be is 1.58 cells (the block touches the road along an edge) and the next is 2.12 (a diagonal corner only); 1.6 keeps the first and rejects the second. Without the touching rule, 3 road cells in reach almost always mean touching, but with a detour on, 1 placed block in 6,000 maps reached its 3 cells only through diagonal corners (and 11 of the first 6,000 maps had such a candidate), so the rule stays. Over thousands of seeds of the game board no socket is out of reach, no map is short of 12 blocks, and 0.1% of roads are drawn again with the detour off (2 in 3,000 seeds; 0.4% with it on).

**Effect on the baseline (seeds 1 to 8, 20 waves, the three original profiles):** the bot now clears 20 waves on all 24 runs, against 21 of 24 before, and most runs end with 14 to 20 Heartstone health. Socket counts changed per seed (seed 1 went from 20 to 16, seed 7 from 14 to 22), and the three lost runs of the old baseline (waves 8 to 10) are now wins. The game got easier, so the pass below starts from a game that the bot never loses.

## The Golem splits (#187)

The Cardboard Golem now leaves four Scrap Goblins behind when it is destroyed (not when it leaks). Measured on seeds 1 to 8, 20 waves, the three original profiles, on `main` before and after the change (the tables above were already out of date because of the socket fix): 7 of the 24 runs now leak where `main` leaked nothing (spool-only on seeds 1, 2, 5 and 6, Heartstone health 20 to 16, 18, 16 and 16; mortar-heavy on seeds 2, 3 and 5, 20 to 16), and all 24 runs still clear 20 waves. In those runs wave 10 goes from 0 leaks to 4: the Golem dies near the end of the road, so its goblins start a few cells (at most 1.2) from the end and walk out before the towers can retarget. So wave 10 now costs about 4 Heartstone health on roughly one run in three, which is the point of a boss. The children do not inherit the Golem's slow, and a Golem destroyed within 1.2 cells of the start stacks its children on the spawn point. Any balance round that merges after this one must be re-measured.

## Interim balance (2026-10-12)

**Goal (owner, 2026-10-12):** a light pass now, a full one after the Phase 7 content (guards, heroes, spells, flyers, support foes). The aim is that a build of only one kind of tower can carry a run about as far as the others, that a mix is at least as good as the best of them, and that waves 11 to 20 push back. These numbers are interim: guards that block foes, heroes and spells will change the power of everything, and the economy has nothing to buy late in the game (the Spool Guard strategy ends with about 1,200 unspent Buttons).

**Method:** the scripted bot with four profiles (`spoolOnly`, `mortarHeavy`, `prismHeavy`, `mix`) on seeds 1 to 8 (1 to 16 where noted), 20 waves. `prismHeavy` builds Prism Spire, Spool Guard, Prism Spire in turn, so it is not Prism-only. Every round below was run on the current `main` (sockets beside the road, the Golem splitting), through `scripts/balance_sweep.py`; the exact configurations and the raw output are in `docs/balance/` (`rounds-seeds-1-8.json` and `.txt`, `rounds-seeds-1-16.json` and `.txt`), so each line can be reproduced. "Won" is a run that clears all 20 waves; a run that stops at 19 waves cleared without dying hit the 30-minute play cap and does not count as won; the numbers are the medians of the waves cleared, or the wins out of the maps.

**What the rounds showed**

| Round | Numbers | Spool only | Mortar heavy | Prism heavy | Mix |
| --- | --- | --- | --- | --- | --- |
| R1a | Prototype numbers, HP growth 0.014 | 8 of 8 won | 8 of 8 won | 2 of 8 won, median 10 | 8 of 8 won |
| R1b | Prototype numbers, HP growth 0.03 | 5 of 8 won | 8 of 8 won | 0 of 8 won, median 8.5 | 5 of 8 won |
| R2a | R1b with Prism damage 32 / 66 / 130 | 5 of 8 | 8 of 8 | 3 of 8, median 18.5 | 8 of 8 |
| R2b | R2a with Prism cost 90 / 90 / 150 | 5 of 8 | 8 of 8 | 8 of 8 won | 8 of 8 |
| R3a | R1b with Orc armor 8 | 0 of 8, median 7 | 8 of 8 won | 0 of 8, median 8 | 1 of 8, median 9 |
| R3b | HP 0.03, Orc armor 6, Prism 32 / 66 / 130, Spool 11 / 18 / 30, Mortar 32 / 56 / 96 | 8 of 8 | 8 of 8 | 3 of 8, median 18.5 | 8 of 8 |
| R4a | The final numbers below, HP growth 0.05 | 0 of 8, median 17 | 3 of 8, median 15 | 1 of 8, median 14 | 2 of 8, median 14 |
| R4b | Final numbers, HP growth 0.06 | 0 of 8, median 14 | 2 of 8, median 11 | 0 of 8, median 12 | 1 of 8, median 11.5 |
| R4c | Final numbers, HP growth 0.07 | 0 of 8, median 10 | 0 of 8, median 10 | 0 of 8, median 9.5 | 0 of 8, median 10.5 |

1. **The Prism Spire is the weak tower.** With the prototype's numbers a Prism-heavy build is lost on waves 7 to 13 on most maps while the others win (R1a, R1b). 16 damage per second for 110 Buttons is about a quarter of a Spool Guard's damage per Button. Doubling its damage alone is not enough (R2a); doubling it and cutting the cost to 90 makes it win everything (R2b), so the final numbers sit between: damage 36, 72, 140 per second at 100, 90, 160 Buttons.
2. **Orc armor is what separates the towers.** At armor 8 the Spool Guard and Prism-heavy builds collapse (they cleared 6 to 9 waves and won no map) and the Mix nearly does (it won 1 of 8 maps, the others ending on waves 8 to 10), while the Mortar's splash still wins every map (R3a). At 6, with the Spool Guard raised about 20% (9, 15, 26 to 11, 18, 30), the Spool Guard is back in the game (R3b).
3. **The Mortar needs a trim, but a smaller one than I first made.** With the final numbers at HP growth 0.04 (seeds 1 to 16, `rounds-seeds-1-16`): the untrimmed Mortar (32 / 56 / 96) wins 14 of 16 maps against 9 for the Spool Guard and 7 for Prism-heavy; 26 / 46 / 80 wins 6 of 16 (too weak); 29 / 51 / 88 wins 10 of 16. That is the number used.
4. **Foe HP growth sets the difficulty once the towers are close to each other.** At 0.04 the strategies win 7 to 12 of 16 maps and the weak maps are lost between waves 11 and 20; 0.05 is harder than the target (0 to 3 of 8 won), 0.06 and 0.07 are much too hard.

**Changes** (all in `godot/content`):

| Number | Before | Now |
| --- | --- | --- |
| Corrugated Orc armor | 4 | 6 |
| Foe HP growth, quadratic term (`HP_QUADRATIC`) | 0.014 | 0.04 |
| Spool Guard damage, levels 1 to 3 | 9, 15, 26 | 11, 18, 30 |
| Thimble Mortar damage | 32, 56, 96 | 29, 51, 88 |
| Prism Spire damage per second | 16, 33, 65 | 36, 72, 140 |
| Prism Spire cost | 110, 100, 180 | 100, 90, 160 |

**Result** (seeds 1 to 16, 20 waves, `rounds-seeds-1-16` configuration R5c):

| Strategy | Median waves cleared | Range | Won | Mean Heartstone health at the end | Buttons left |
| --- | --- | --- | --- | --- | --- |
| Spool Guards only | 20 | 17 to 20 | 9 of 16 | 7.3 | 1,193 |
| Mortar heavy | 20 | 10 to 20 | 10 of 16 | 5.8 | 297 |
| Prism heavy | 19 | 15 to 20 | 7 of 16 | 5.1 | 129 |
| Mix | 20 | 10 to 20 | 12 of 16 | 10.1 | 486 |

Solo builds are within a wave of each other in median, they win 7 to 10 of 16 maps, and the mix wins the most (12 of 16) with the highest Heartstone health. Mortar heavy and Mix have the worst maps (both end on wave 10), and Prism heavy has the lowest Heartstone health at the end (5.1). Only one run in the 64 ends with the Heartstone untouched. Still to do: the economy (Buttons pile up), the boss wave as a real test, the targets of #203 for the first four waves, and everything involving the new content.

## Bigger swarms (2026-10-12, #216)

The owner found the game too easy and asked for bigger swarms. A swarm wave (every 5th wave that is not a boss wave: 5 and 15) now has more foes, more orcs and tougher goblins that pay less. The ticket scoped only the count; the other three rules were added because the count alone does not work (below), and are recorded here and on #216.

| Number (`godot/content/waves.gd`) | Before | Now |
| --- | --- | --- |
| `SWARM_COUNT_MULTIPLIER` (foes in a swarm, times the usual count) | 1.0 | 1.5 (wave 5: 13 to 20 foes; wave 15: 27 to 41) |
| `SWARM_ORC_THRESHOLD_DROP` (the orc threshold of a swarm is the normal one minus this) | no orcs | 0.1 (about 1 foe in 3 at wave 5, 2 in 5 at wave 15) |
| `SWARM_HP_MULTIPLIER` (swarm Scrap Goblin hp) | 1.0 | 2.0 |
| `SWARM_REWARD_MULTIPLIER` (swarm Scrap Goblin Buttons) | 1.0 | 0.5 |

**Why not only a bigger count.** The sweeps are in `docs/balance/swarms-candidates-seeds-1-16.txt` (produced by `scripts/balance_sweep.py`, one block per set of numbers). Multiplying only the count (x1.4 and x1.8) made the game easier: more strategies reached wave 20 and the Heartstone ended with more health (Mortar heavy 5.8 to 9.1 at x1.8). A Scrap Goblin has 20 hp at wave 1 and pays Buttons, so a bigger swarm of frail goblins dies to splash and beams and pays for more towers. The swarm needs weight (hp, orcs) and a smaller reward.

**Why these numbers.** A first set with the swarm orc threshold fixed at 0.75 left a swarm with fewer orcs than the waves around it late in the run and barely changed the total (41 wins of 64; its block is at the end of the candidates file). Taking the swarm threshold from the normal one fixes that. Drop 0.05, 0.1 and 0.15 win 35, 32 and 26 of 64; the harsh sets of the first round (x1.6 with hp x3, x2 with hp x4) win 33 and 11 of 64 but kill the Prism-heavy build on wave 15 on 13 of 16 maps or lose most runs, mostly on wave 15. Drop 0.1 is the middle: noticeably harder, every strategy can still win.

**Result** (seeds 1 to 16, 20 waves, `swarms-seeds-1-16.txt`; "before" is `rounds-seeds-1-16` R5c):

| Strategy | Won before | Won now | Mean Heartstone health before | now |
| --- | --- | --- | --- | --- |
| Spool Guards only | 9 | 7 | 7.3 | 6.6 |
| Mortar heavy | 10 | 12 | 5.8 | 8.7 |
| Prism heavy | 7 | 5 | 5.1 | 3.9 |
| Mix | 12 | 8 | 10.1 | 6.9 |

**What it says.** Wins fall from 38 to 32 of 64 and 22 of the 25 losses are on wave 15, the swarm: the swarm is now a real test, which was the aim. Two things to know. First, the Thimble Mortar barely notices (12 of 16 wins, its splash is the counter to a swarm), so the Mix (8 of 16) now wins less than the best solo build, against the interim rule that a mix should be at least as good; the post-Phase 7 balance pass (#203) should settle that, probably with a stronger answer to swarms for the Spool Guard and the Prism Spire or a weaker Mortar. Second, the Buttons that every strategy still ends with (200 to 1,000) show the economy is the real reason the game is easy; extra pressure only helps so far while the player can buy it off. Runs that neither won nor lost stopped at the 30 minute cap of the bot runner (the runner prints 30.0 minutes for them); they are counted in neither column.

## Guard Tent and Kitchen Mess Tent (2026-10-13, #223)

The scripted bot got a profile with both tents, `guardMix` (`spoolGuard`, `thimbleMortar`, `prismSpire`, `spoolGuard`, `guardTent`, `thimbleMortar`, `messTent`, `prismSpire`; the tents go in slots 5 and 7, after the damage towers). The Guard Tent goes on the free socket that reaches the most road, like any tower; the Mess Tent on the free socket whose aura reaches the most guards (none before a Guard Tent stands; when no socket suits it the bot builds the next tower of its order). Raw sweeps: `docs/balance/tents-candidates-seeds-1-16.txt` (all produced by `scripts/balance_sweep.py`; `BALANCE_PROFILES=guardMix` plays one profile) and `tents-seeds-1-16.txt` (the final numbers, all five profiles).

**What the first numbers did.** With the first proposal (Guard Tent 70/80/140 Buttons, guards 60/100/170 hp and 4/7/12 damage, respawn 12/10/8 s) a profile with tents in half its slots won 0 of 16 maps, and with tents in 2 of 8 slots 2 of 16 (the plain mix wins 8). The guards' blows were cut to a quarter by the Orc's armor and a tent cost more than a Spool Guard, so a tent was a bad use of Buttons; tents in half the slots also starved the economy. Stronger guards helped step by step (a tent-light order with the first numbers won 2 of 16, 1 of 16 without the Mess Tent, and 1 of 16 with 2x damage and hp; then 2, 4, 5 and 7 wins as guards got tougher, cheaper and faster to return); those rounds ran with the Mess Tent aura at 2.2 cells, which almost never had a socket to stand on: over seeds 1 to 40, with every socket tried as the place of a Guard Tent (642 tents), only 36 percent had another socket within 2.2 cells of their post (57 percent within 3.0, 66 percent within 3.3, 87 percent within 3.6; method and figures in `godot/tools/aura_coverage.gd` and `docs/balance/aura-coverage.txt`). So the aura is now 3.0, 3.3 and 3.6 cells, which reaches a spot for a level 1 tent on about 57 percent of Guard Tents and for a level 3 tent on about 87 percent.

| Number (`godot/content/towers.gd`) | First proposal | Now |
| --- | --- | --- |
| Guard Tent cost | 70, 80, 140 | 55, 65, 110 |
| Guard hp | 60, 100, 170 | 120, 200, 320 |
| Guard damage per blow | 4, 7, 12 | 16, 28, 48 |
| Guard respawn (s) | 12, 10, 8 | 6, 5, 4 |
| Mess Tent aura (cells) | 2.2, 2.5, 2.8 | 3.0, 3.3, 3.6 |

**Result** (seeds 1 to 16, 20 waves, `tents-seeds-1-16.txt`):

| Strategy | Won | Mean Heartstone health | Buttons left |
| --- | --- | --- | --- |
| Spool Guards only | 7 | 6.6 | 985 |
| Mortar heavy | 12 | 8.7 | 498 |
| Prism heavy | 5 | 3.9 | 204 |
| Mix | 8 | 6.9 | 510 |
| Guard mix (Guard Tent and Mess Tent) | 6 | 5.1 | 380 |

**What it says.** The Guard Tent is now a usable choice and not a better one: the guard mix wins 6 of 16, between Prism heavy (5) and the plain mix (8). The Mess Tent is not yet worth its price: the same guard numbers at an aura of 2.2 cells (where the bot rarely found a socket for a Mess Tent and built the next tower instead) won 7 maps with 390 Buttons left, and at 3.0 cells (where it does build it) 6 maps with 380 left, so building the Mess Tent cost a map, which is within noise but not a gain. It is recorded as a known-weak support (100 to 160 Buttons for +12 to +25% blows and +2 to +4 hp a second) for the post-Phase 7 pass (#203), where its bonus or its cost should change. That is the intended role (the GDD's tent holds and supports; the damage comes from the towers), but the bot cannot show the tent's real value, which is holding the one dangerous foe where several towers reach it, and the Golem is not blockable. A player will use it better than the bot does, so the numbers err on the side of not being strong. Not done here: tier 4 specs, the hero, the Camp Cook.

## Final balance pass for Phase 4 (2026-10-13, #203)

The ticket's targets, measured with the scripted bot on seeds 1 to 12 (`godot/tools/balance_run.gd --detail`) before the change and on seeds 1 to 16 after (`docs/balance/final-pass-seeds-1-16.txt`, all five profiles).

| Target | Before this pass | Now |
| --- | --- | --- |
| Waves 1 to 4 are safe for a sensible start | Met: no Heartstone health lost in waves 1 to 4 in any profile (0.00 leaks per wave) | Unchanged: 0.00 leaks in waves 1 to 4 in every profile on seeds 1 to 16 (`docs/balance/final-pass-detail-seeds-1-16.txt`) |
| The first boss (wave 10) is a real test | Met: the average run leaks 1.0 to 1.6 foes in wave 10 and clears it; the guard mix lost 1 of 12 there; a bot that builds nothing loses (`test_bot_runner`) | The average run leaks 1.2 to 1.6 foes in wave 10 (the `--detail` file above). Mortar-heavy loses 3 of 16 on waves 9 and 10 (it lost none on seeds 1 to 12 before) and the guard mix 1; the three Mortar losses (seeds 1, 6, 13) end with 14 to 18 level 0 Mortars and under 40 Buttons, so they say as much about the bot's build order as about the boss |
| Several strategies reach the boss; none wins to wave 20 with ease | Missed by one: Mortar-heavy won 12 of 16 maps (75%; 10 of 12 on seeds 1 to 12) with 0.7 leaks in wave 20; the others won 5 to 8 of 16 (Spool 7, Prism 5, Mix 8, guard mix 6, from the sections above) | Met: Spool 7, Mortar 6, Prism 5, Mix 7, guard mix 6 of 16 (31% to 44%) |
| The Orc needs the Prism Spire or upgrades; the swarm needs the Thimble Mortar | Met: on seeds 1 to 12 the builds without a Mortar lose on the swarm wave 15 (Spool 5 losses, Prism 6, Mix 3) and Mortar-heavy loses none there | The swarm half still holds: the builds without a Mortar lose on wave 15 (Spool 7 of 7 losses, Prism 9 of 10, Mix 6 of 7); Mortar-heavy 2 of 7. The Orc half is not measured by a sweep: it rests on the damage rules (`test_damage`, `test_prism_beam`: the beam ignores armor, a Spool Guard blow loses 6) |

**The one change.** Thimble Mortar damage 29, 51, 88 to 27, 48, 83 (about 7 percent less). Candidate trims on seeds 1 to 12, Mortar-heavy wins: 27/48/83 gave 6 of 12, 25/45/77 gave 4 of 12 and 23/41/71 only 1 of 12 (raw output in `docs/balance/mortar-trims-seeds-1-12.txt`, with the 12-seed tables from before the trim): the Mortar's win rate is very sensitive to its damage, so the smallest trim that brought it down was taken. On 16 seeds Mortar-heavy went from 12 to 6 wins and the Mix from 8 to 7 (6 to 5 on seeds 1 to 12), so the Mix is no better off for it; what changed is the spread: from 12 against 5 (Mortar against Prism) to 7 against 5, and the best builds now sit level (Spool 7, Mix 7) where the Mortar was 4 wins ahead of the next one.

| Strategy | Won (of 16) | Mean Heartstone health | Buttons left |
| --- | --- | --- | --- |
| Spool Guards only | 7 | 6.6 | 985 |
| Mortar heavy | 6 | 5.3 | 377 |
| Prism heavy | 5 | 3.9 | 204 |
| Mix | 7 | 6.2 | 404 |
| Guard mix (Guard Tent and Mess Tent) | 6 | 4.1 | 325 |

**What stays open, for the pass after the Phase 7 content** (#237): the economy still leaves 200 to 1,000 Buttons unspent in every strategy (the extra pressure is bought off, see the swarm section); the Mess Tent is a weak support for its price; Prism heavy is the weakest build against swarms; Razor Moths, the Ink Shaman, tier 4 specs, the hero and spells all change the balance. The replay goldens were regenerated for this change (a reviewed balance change); the same games win and lose, but their ticks, final Heartstone health and Buttons changed.

## Waves in Fibonacci groups (2026-10-13, #240)

The owner asked for bigger batches of enemies in random groups of Fibonacci sizes up to 21, and a little more speed. Owner answers: bigger waves (not the same total) and slightly faster foes.

**What changed** (`godot/content` and `godot/sim/waves/wave_builder.gd`):

- A wave has 1.4 times as many foes (`WAVE_SIZE_MULTIPLIER`): wave 1 has 10, wave 10 has 28 plus the escort and the Golem, wave 20 has 48, swarm waves 27 (wave 5) and 57 (wave 15).
- The foes of a wave are cut into groups of 1, 2, 3, 5, 8, 13 or 21 (`GROUP_SIZES`), one draw of the waves stream per group. The biggest group a wave may have rises with the wave: 5 foes up to wave 3, 8 from wave 4, 13 from wave 8, 21 from wave 13. Inside a group each foe follows 0.14 s behind the one before; between groups there is a pause of 2.4 s less 0.05 s per wave (at least 1.0 s). The boss escort and the Golem keep their own gaps.
- Foes are about 12 percent faster: Scrap Goblin 1.9 to 2.13, Corrugated Orc 0.68 to 0.76, Cardboard Golem 0.5 to 0.56 cells a second.
- Every kill pays 0.9 times as much (`REWARD_MULTIPLIER`): bigger waves pay more Buttons.
- Towers: Spool Guard damage 11, 18, 30 to 13, 21, 35; Prism Spire damage per second 36, 72, 140 to 42, 84, 163; Thimble Mortar damage 27, 48, 83 to 22, 40, 68.

**Why the towers moved.** The raw sweeps are in `docs/balance/groups-candidates.txt` (seeds 1 to 8, then 16 for the last round). With only the waves and the speed changed, the economy was the first problem: reward 1.0 left 1,300 to 2,000 Buttons unspent, and reward 0.8 collapsed every strategy by wave 10; 0.9 sits between. The second was that groups are what the GDD says a goblin swarm is, a job for splash: with the old tower numbers the Spool-only and Prism-only builds never won a map at any reward setting (0 of 8) while Mortar-heavy won 5 to 7 of 8. So the single-target towers went up by about 18 percent and the Mortar down by about 18 percent; two earlier sets (Spool 14, 22, 37 and Prism 44, 88, 171 with the Mortar at 25, 45, 77, and the same with the Mortar at 22, 40, 68) won 7 to 13 of 16 maps for each strategy, easier than before the change.

**Result** (seeds 1 to 16, 20 waves, `docs/balance/groups-final-seeds-1-16.txt`; "before" is the final pass above):

| Strategy | Won before | Won now | Mean Heartstone health | Buttons left |
| --- | --- | --- | --- | --- |
| Spool Guards only | 7 | 7 | 4.2 | 2,093 |
| Mortar heavy | 6 | 6 | 3.2 | 565 |
| Prism heavy | 5 | 4 | 3.1 | 757 |
| Mix | 7 | 9 | 6.6 | 1,339 |
| Guard mix | 6 | 6 | 3.3 | 860 |

**What it says.** The win rates sit where they did (25 to 56 percent) but the game is a different one: waves are bigger and faster, arrive in clumps, and the losses fall earlier in the single-target builds (Prism heavy loses on waves 12 to 15 on 7 of its 11 losses). The Mix is now the best build (9 of 16), which is the intended direction: splash for the groups and single-target for the Orcs and the boss. Still true: Spool-only ends with about 2,000 unspent Buttons (it cannot spend them on anything that helps), which is the economy item of #237. The sweeps change little between 16 seeds and 8: results move by one or two maps, so numbers within that are noise. The replay goldens were regenerated for this reviewed change.

