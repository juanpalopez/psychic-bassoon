# Balance

The numbers of the sim (foes, towers, economy) started from the 2D prototype's, whose road was short (a 9 by 13 board). This file records what headless runs of the scripted bot say about them, so a change to a number can be judged by its effect and not by feel. The owner tunes; Claude proposes and measures.

## How to run it

```bash
godot --headless --path godot -s tools/balance_run.gd -- --seeds=1,2,3,4,5,6,7,8 --waves=20 --detail
```

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

The owner found the game too easy and asked for bigger swarms. A swarm wave (every 5th wave that is not a boss wave: 5, 15) now has more foes, a few orcs and tougher goblins that pay less.

| Number (`godot/content/waves.gd`) | Before | Now |
| --- | --- | --- |
| `SWARM_COUNT_MULTIPLIER` (foes in a swarm, times the usual count) | 1.0 | 1.5 |
| `SWARM_ORC_THRESHOLD` (a roll above this makes an orc in a swarm) | no orcs | 0.75 (about 1 foe in 4) |
| `SWARM_HP_MULTIPLIER` (swarm Scrap Goblin hp) | 1.0 | 2.0 |
| `SWARM_REWARD_MULTIPLIER` (swarm Scrap Goblin Buttons) | 1.0 | 0.5 |

**Why not only a bigger count.** Raw sweeps are in `docs/balance/swarms-candidates-seeds-1-16.txt`. Multiplying only the count (×1.4 and ×1.8) made the game easier: more strategies reached wave 20 and the Heartstone ended with more health (Mortar heavy 5.8 to 9.1 at ×1.8). A Scrap Goblin has 20 hp at wave 1 and pays Buttons, so a bigger swarm of frail goblins dies to splash and beams and pays for more towers. The swarm needs weight (hp, a few orcs) and a smaller reward.

**Why these numbers.** Harsher sets killed the Prism-heavy build on wave 15 (×1.6, threshold 0.7, hp ×3: 13 of 16 maps lost at wave 15; ×2, hp ×4: every strategy collapsed). The set above keeps every strategy able to win and moves the losses to the swarm waves.

**Result** (seeds 1 to 16, 20 waves, `swarms-seeds-1-16.txt`; the numbers before are `rounds-seeds-1-16` R5c):

| Strategy | Won before | Won now | Mean Heartstone health before | now |
| --- | --- | --- | --- | --- |
| Spool Guards only | 9 | 10 | 7.3 | 9.1 |
| Mortar heavy | 10 | 13 | 5.8 | 9.0 |
| Prism heavy | 7 | 6 | 5.1 | 4.7 |
| Mix | 12 | 12 | 10.1 | 10.3 |

**What it says.** The swarm change does not make the game harder overall: the wave counts changed the waves' random draws, so single maps moved either way, and the totals are about the same (38 wins of 64 before, 41 now). Prism heavy is the build that swarms hurt (it wins 6 of 16 maps, down from 7, and its worst losses are on waves 15 to 19), which fits its role (a single beam against many bodies). What keeps the game easy is the economy: every strategy ends with 200 to 1,400 unspent Buttons, so extra pressure just gets bought off. The balance pass after Phase 7 (#203) should add a sink for Buttons or scale the late waves. Swarms stay in the game as a distinct kind of wave.
