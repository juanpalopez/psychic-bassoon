# Balance

The numbers of the sim (foes, towers, economy) started from the 2D prototype's, whose road was short (a 9 by 13 board). This file records what headless runs of the scripted bot say about them, so a change to a number can be judged by its effect and not by feel. The owner tunes; Claude proposes and measures.

## How to run it

```bash
godot --headless --path godot -s tools/balance_run.gd -- --seeds=1,2,3,4,5,6,7,8 --waves=20 --detail
```

Options: `--seeds=` (comma-separated map seeds), `--profiles=` (`spoolOnly`, `mortarHeavy`, `mix`; see `godot/content/bot_profiles.gd`) and `--waves=` (waves to clear; the run also stops when the Heartstone falls or after 30 minutes of play). `--detail` adds the wave tables below. Twenty-four runs of about 20 minutes of play each take about a minute.

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

- **The game is far too easy after the first boss.** The bot clears 20 waves on 21 of the 24 runs. It builds a tower on every socket (the `sockets` and `towers` columns match on every run) and ends with most towers at level 3. It still holds unspent Buttons: 700 to 2,000 for the Spool Guard strategy, 250 to 1,000 for the other two, which finish with some towers at level 2. The economy runs out of things to buy.
- **The first boss is the only real test.** Wave 10 (the Cardboard Golem and an escort) leaks on most runs (the Golem costs 6 Heartstone health when it gets through). The three lost runs (Spool Guards only on seeds 1 and 5, the mix on seed 5) die on waves 8 to 10, with only 13 to 20 towers built and almost none upgraded: the bot was behind on Buttons, not out-fought late. The Golem does not split into Scrap Goblins yet (#187), so the boss is easier than designed.
- **Waves 1 to 3 are safe, waves 4 to 9 leak a little**, which matches the target for the early game.
- **The long road helps the player.** The main road is about 71 cells on the 22 by 16 board against about 33 on the old 9 by 13 one (the `mean main road` line of the `--detail` output, over seeds 1 to 8), so the same tower numbers get more than twice the time on target.
- **Strategies hardly differ.** Spool Guards alone, Mortar-heavy and the mix all clear the same waves, so the Orc counter and the swarm counter do not matter yet.

## Limits of the bot

- It saves up for its next tower and upgrades nothing until every socket has a tower, which is why the lost runs show almost no upgrades: they were still building when the waves caught up.
- The per-wave rows count kills and leaks since the previous clear. A game that ends in the middle of a wave keeps those numbers in `unfinished`, and with early calls kills belong to the wave that clears next.
- It never sells, never moves a tower and plays one fixed build order per profile.
