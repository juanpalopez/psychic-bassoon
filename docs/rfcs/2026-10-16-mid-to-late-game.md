# RFC: Improving the mid-to-late game of Papercraft Kingdom Defense

Status: draft for the owner · 2026-10-16 · Phase 7 · Author: Claude (Opus), from an earlier Opus memo, research tasks T1 to T8 and T10, and a repo cost pass (T9, done here). The research tasks T1 to T10 are summarised in the sections that cite them; their raw reports are not stored in the repo.

## 1. Problem statement

An earlier Opus memo ran the scripted bot (profiles `mix`, `spoolOnly` and others, seeds 1 to 8) and measured the following:

- The bot stops building at wave 7, because the sockets are full (12 on about three maps in four, `docs/BALANCE.md`, Map v3). Every tower is level 3 by wave 15 (`TOWER_LEVELS := 3`).
- Buttons pile up: 259 at wave 15 grows to 3,007 at wave 20. Sweeps end with 1,400 to 3,800 Buttons unspent (Map v3 recorded 1,478 to 3,272).
- Foe hp scales x6 at wave 10, x11.6 at wave 15 and x18.2 at wave 20. Waves hold 28 to 48 foes and take 40 to 75 s at 1x. Losses fall on waves 17 to 20.
- The player has six commands: build, upgrade, sell, launch wave, choose spec and activate ability. Tier-4 actives have cooldowns of 18 to 30 s and aim at the tower's own target. There is no targeting priority, hero or spell. An early call pays `10 + 2w` Buttons.

So from about wave 8 the player has nothing to decide and nothing to spend on. They watch a game they can no longer change.

**Two caveats from the repo:**

1. The bot is still spec-blind (`docs/lessons/2026-10-16-tier4-framework.md`: "the bot stays spec-blind until then").
2. Every profile has `call_early: false` (`godot/content/bot_profiles.gd`).

Tier 4 costs 140 to 160 Buttons per tower (`godot/content/specs.gd`). On 12 sockets that is about 1,700 to 1,900 Buttons. Part of the measured surplus may therefore come from the bot rather than the game, so the first ticket measures again.

## 2. Goals and non-goals

**Goals**

- Give the player a real decision in waves 8 to 20 at least every 20 s, measured by the bot.
- Turn surplus Buttons into a trade-off. Target: under 500 unspent at wave 20.
- Keep the win band at 4 to 9 of 16 seeds for every profile.
- Keep the sim deterministic. With a feature's flag off, the existing goldens stay byte-identical.
- Prefer systems the GDD already plans for Phase 7.

**Non-goals**

- Meta progression and Golden Staples (Phase 8).
- New art beyond decals, icons and cards.
- Branching routes.
- An endless mode.
- Monetisation of any kind.

## 3. Lessons from shipped games

Sourcing is thin. Many wiki pages returned 402 or 403, and several claims come from snippets or secondary summaries. Treat them as leads (see Sources and confidence).

- **Ability cadence (T1).** BTD6 tier-5 actives use cooldowns of 20 to 60 s, and most start at about a third of their cooldown. Kingdom Rush gives the player two always-available verbs: reinforcements on a 10 s cooldown and Rain of Fire on 80 s. Our 18 to 30 s actives sit in this band. What they lack is a choice of _where_, not _when_.
- **Sinks (T3).**
  - BTD6 Paragons merge towers and let money add power, up to a cap.
  - Bank towers stop producing at a cap.
  - Sell refunds run from 60% (Kingdom Rush) to 80% (BTD6). Ours is 70%.
  - Interest on banked gold makes hoarding worse.
  - T3 suggests three patterns: a capped capstone above level 3, a cheap respec, and a priced emergency spend whose price rises with each use.
- **Pacing (T7).** A generic hp curve grows x1.1 to x1.2 per wave. Ours slows to x1.07 per wave by wave 20, below that band. Late difficulty is therefore not too steep. The real problem is that tower power plateaus at wave 13 to 15.
- **Failures (T10).**
  - Resource-recharge timers felt like dead time (Heroes of the Storm tower ammunition was removed).
  - A single dominant stat turns the late game into a solved loop (idle TD commenters).
  - Paid tap gestures were called cheating (PvZ2 Plant Food).
  - Upgrade gates were read as monetisation (BTD6 Monkey Knowledge).
- **Drafts (T2).**
  - Three options is the common baseline (TFT, Vampire Survivors, Rogue Card TD).
  - Every option should have a purpose (the Slay the Spire GDC talk, via a summary).
  - Rerolls should be scarce.
  - No offer should be all economy.
  - Nothing was found on how to design bargains (a cost for a reward).

## 4. Candidates, hard filters and cost (T9)

**Hard filters.** A candidate is dropped if any of these holds:

- It needs a draw from the map or combat streams.
- It needs a branching route.
- It cannot be a tick-stamped command the bot can issue.
- Its main control needs a target under 44 px, or a gesture that conflicts with one-finger pan (T4).

**Dropped:**

- **Ink seepage and collapsing bridges.** They need a changing or branching route.
- **Spool overdrive by winding.** A circular gesture conflicts with pan (T4).
- **Scrap harvesting by swipe.** Conflicts with pan (T4). A tap-to-collect variant is kept below.

**T9: cost from the repo** (S, M, L per layer).

| Candidate                                                                    | Sim            | UI  | Art         | Bot | Notes from the code                                                                                                                                                                                                                                  |
| ---------------------------------------------------------------------------- | -------------- | --- | ----------- | --- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Ink Blots (the Ink Shaman blots a tower, a tap clears it)                    | S              | S   | S (a decal) | S   | A `blotted` field on `Tower`, a timer in `support/shaman_aura.gd`, and a `CLEAR_BLOT(tower_id)` command. Target choice is deterministic: the nearest tower, ties broken by id. No new foe.                                                            |
| Toolbox Tray spells and Crafting Energy, plus Ink bought with Buttons        | M              | M   | S (decals)  | M   | `Command` already carries `col` and `row`. The `specs/zones.gd` pools and slows cover the glue trap. Thumbtacks need a fixed tack pattern from content, never random. The Eraser reuses the armor strip in `combat/status.gd`.                       |
| Heartstone Mending (Buttons for health, price rises with each use)           | S              | S   | none        | S   | One command, a counter, and a price list in `game_rules.gd`.                                                                                                                                                                                         |
| Workbench Draft (1 of 3 cards after waves 3, 6, 9, 12, 15 and 18)           | M              | M   | S (cards)   | M   | A new `Streams.DRAFT := 5`, a `CHOOSE_DRAFT` command, and effects as `kind` handlers (the specs pattern).                                                                                                                                           |
| Cut a new socket late (rising price)                                         | M              | M   | S           | S   | The candidates come from the existing `socket_placer.gd` rules, and the bot reuses `_rank_sockets`.                                                                                                                                                  |
| Targeting priorities                                                         | S              | S   | none        | S   | `tower_fire.target_for` has one rule (least distance left, Shaman first).                                                                                                                                                                            |
| Tap-to-collect scraps (pays Crafting Energy)                                 | M              | M   | S           | S   | Drops need sim entities. It depends on the spells, and each scrap needs a 44 px hit area.                                                                                                                                                            |
| Messenger Crow orders                                                        | S              | S   | none        | S   | `ui/crow_alerts.gd` exists. The rewards would add Buttons, which feeds the hoard.                                                                                                                                                                    |
| Masterwork tier above tier 4                                                 | S              | S   | M           | S   | Contradicts the GDD's "strict 4-tier" path.                                                                                                                                                                                                          |
| Shred a tower for a burst                                                    | S              | S   | S           | S   | A variant of sell.                                                                                                                                                                                                                                   |
| Paperclip Grunts (a sixth foe)                                               | M              | S   | L           | S   | Needs a new model through the Scrap Goblin pipeline and the owner's approval.                                                                                                                                                                        |
| Aimed tier-4 actives (tap the badge, then tap a cell)                        | M (10 handlers) | M   | none        | M   | Reverses a tier-4 decision.                                                                                                                                                                                                                          |
| The hero, the Knight of Cardboard                                            | L              | M   | L (skinned) | M   | Reuses guard combat from `barracks/`.                                                                                                                                                                                                                |
| Desk fan gusts                                                               | M              | S   | S           | S   | Adds little to decide.                                                                                                                                                                                                                               |
| Splitters and origami folders                                                | M              | S   | L           | S   | `combat/splitting.gd` exists, but both need new foe models.                                                                                                                                                                                          |

**Scoring matrix.** Each criterion scores 0 to 3, and the weight is in brackets. The criteria are:

- D: decision density in waves 8 to 20 (x3)
- S: absorbs Buttons (x2)
- F: fit with the GDD (x2)
- R: determinism and golden safety (x2)
- B: the bot can play and evaluate it (x2)
- C: inverse scope (x2)
- E: phone ergonomics (x1)
- A: anti-dominance (x1)

The maximum score is 45.

| Candidate                           | D   | S   | F   | R   | B   | C   | E   | A   | Total  |
| ----------------------------------- | --- | --- | --- | --- | --- | --- | --- | --- | ------ |
| Ink Blots on the Ink Shaman         | 3   | 0   | 2   | 3   | 3   | 2   | 2   | 3   | **34** |
| Toolbox Tray spells and bought Ink  | 3   | 2   | 3   | 3   | 1   | 1   | 2   | 2   | **33** |
| Heartstone Mending                  | 1   | 3   | 1   | 3   | 3   | 3   | 3   | 1   | **33** |
| Workbench Draft                     | 2   | 2   | 1   | 3   | 2   | 2   | 3   | 1   | 30     |
| Cut a new socket                    | 1   | 3   | 1   | 3   | 2   | 2   | 3   | 2   | 30     |
| Targeting priorities                | 1   | 0   | 3   | 3   | 2   | 3   | 3   | 2   | 30     |
| Tap-to-collect scraps               | 3   | 0   | 3   | 3   | 2   | 1   | 1   | 2   | 30     |
| Messenger Crow orders               | 2   | 0   | 2   | 3   | 2   | 2   | 3   | 2   | 29     |
| Masterwork tier                     | 1   | 3   | 1   | 3   | 2   | 2   | 3   | 1   | 29     |
| Shred a tower                       | 1   | 1   | 1   | 3   | 2   | 3   | 3   | 2   | 28     |
| Paperclip Grunts                    | 3   | 0   | 1   | 3   | 3   | 0   | 2   | 3   | 28     |
| Aimed tier-4 actives                | 2   | 0   | 2   | 3   | 1   | 2   | 2   | 2   | 26     |
| The hero                            | 2   | 1   | 3   | 3   | 1   | 0   | 2   | 2   | 26     |
| Desk fan gusts                      | 1   | 0   | 2   | 3   | 2   | 2   | 3   | 2   | 26     |
| Splitters and folders               | 1   | 0   | 1   | 3   | 3   | 1   | 3   | 2   | 24     |

R is 3 everywhere because every survivor is designed with no draw from the map or combat streams. That is a design choice, not a free property, and the ticket tests enforce it.

The scores are judgment calls, not measurements; ticket 1 is how we check them. The earlier memo rated the Draft 5 for impact. It scores lower here because it is foreign to the GDD and carries the solved-meta risk from T10.

## 5. Economy and sinks (T3)

These are proposals; every number comes from sweeps, none from this RFC.

1. **Measure first.** Make the bot spec-aware and let it call waves early. If the surplus drops below 500 Buttons, we may need fewer sinks.
2. **Heartstone Mending.**
   - Command: `MEND_HEARTSTONE`, which restores 1 Heartstone health, capped at `START_HEARTSTONE_HEALTH`.
   - Price: from a content list that rises with each use in a run (T3 pattern 3).
   - It turns a hoard into a choice between insurance now and power later. It is cheap and theme-safe: glue the crystal.
3. **Ink bought with Buttons** (with the spells).
   - Command: `BUY_INK`, which converts Buttons into Crafting Energy at a price that rises with each use.
   - Spells then compete with towers for Buttons. Energy regeneration alone would not absorb anything.
4. **Not now.**
   - A Masterwork tier contradicts the GDD's 4-tier path.
   - Interest would reward hoarding (T3).
   - The refund stays at 70%, inside the 60 to 80% band in T3.

## 6. Agency and determinism (T5)

**Commands**

- New kinds are appended to the end of `Command.Kind`: `MEND_HEARTSTONE`, `CAST_SPELL(spell, col, row)`, `BUY_INK`, `CLEAR_BLOT(tower_id)`, and later `SET_PRIORITY(tower_id, mode)` and `CHOOSE_DRAFT(index)`. Existing enum values never move.
- Commands go through `Game.submit` and apply at the start of the next tick, as today.
- The replay log already stores tick and order (`replays.json`).

**Streams**

- No new mechanic in this plan draws a random number. Thumbtack positions are a fixed pattern from content. The blot target is the nearest tower, ties broken by id.
- If the Draft ships, it gets `Streams.DRAFT := 5`, the next free number; numbers are never reused.
  - Each offer makes a fixed number of draws, so the offer at draft k depends only on the seed and k.
  - A pick consumes no wave, route or map draw.
  - T5 suggested a string label (`deriveRng(seed, "offer", w)`). Our `Rng.derive` takes an integer stream, so we use a fixed draw count instead.

**Flags**

- The repo has no content flag yet. The Moth, the Shaman, the specs and the second source regenerated the goldens instead.
- Add `godot/content/features.gd` with one `bool` const per feature, all off by default. With a flag off:
  1. The command is rejected before it changes anything, and the bot never sends it.
  2. No new stream is drawn from.
  3. **The state hash leaves out the feature's fields.** The golden hashes "the whole state", so a new field such as `ink` or `mend_count` would change every hash even with the flag off. The snapshot writer adds a feature's fields only when its flag is on.
- CI then checks that `replays.json` is byte-identical with every flag off. Each feature adds its own golden with its flag on.

**Already in place:** the checkpoint every 20 s of play already locates the first divergence, which T5 recommends (Factorio's per-tick CRC is the extreme case).

**To add:** `sim_version` and `content_version` in the golden header (T5, from SC2 replays).

## 7. Pressure foes and counterplay (T6)

T6 found that most shipped counters map to verbs we already have: tap, build and retarget. Tower disablers are the closest analogue to a latch-on foe:

- Kingdom Rush's Vez'nan disables towers and can be dispelled after about 10 s.
- Great-T disables every tower for 10 s.
- Correction: Sarelgaz does not disable towers; an earlier assumption said it did.

**Proposal:** keep the GDD's five foes and give the **Ink Shaman** a blot. The GDD's lore is about the ink ("The Blot"), so the fit is close.

- Every N seconds, a Shaman in reach of a tower blots it. A blotted tower stops firing until the player taps it (`CLEAR_BLOT`) or the blot runs out.
- The tap is on the tower's own socket, a 2x2 block well over 44 px, so no confirm tap is needed (T4).
- Second counter: kill the Shaman, which every tower already targets first (`tower_fire.target_for`).
- This adds in-wave taps exactly where the Shamans walk (from wave 7, every 5 waves). It needs no new model.

**Cut:** Paperclip Grunts, which would need a sixth foe, an L-size model and the owner's approval.

## 8. Pacing curve (T7)

Every target below is a proposal. None is sourced as a rule.

- Retune **after** the new mechanics land, because spells and Mending change tower power. Retuning first would be wasted.
- T7's own proposals are:
  - Total wave hp grows about x1.12 per wave from wave 8 to wave 20.
  - Rest waves at about 60% of the previous wave's hp on waves 9, 14 and 17, with spikes on 10, 15 and 18.
  - Rewards rise about 6% per wave from wave 10.
  - A Golem, or a smaller one on wave 15, at 8 to 10 times a normal foe's hp.
- Our schedule already has fixed beats: the Golem every 10 waves, a swarm every 5, Shamans from wave 7, Moths from wave 9 and the second source from wave 11. A rest-then-spike rhythm should line up with those beats, not compete with them.
- Accept a retune only through the protocol in section 9.

## 9. Measuring it (T8)

**Metrics** (the definitions are ours; no source defines them, T8):

- **Attention gap.** The longest stretch of game seconds in waves 8 to 20 with no command from the bot. A second figure leaves out activate-on-ready, because pressing a button when it lights is not a decision.
- **Unspent Buttons** at each wave launch and at wave 20.
- **Smart-minus-random delta.** For each new choice, the wins of the scripted policy minus those of a random-legal policy, using the same derived streams (T8, after the agent-ladder paper).
- **Offer-flip share** (Draft only). Branch both options from the same state and count how often the result changes.
- **Policy spread.** Win counts across profiles.
- **Win band.** Wins out of 16 per profile.

**Acceptance targets**

- No attention gap over 20 s in waves 8 to 20, using the figure without activate-on-ready.
- Under 500 unspent Buttons at wave 20, as the median per profile.
- Every profile wins 4 to 9 of 16.
- The smart-minus-random delta is positive for every new command.

**A/B protocol**

1. The baseline arm is the current `main` with the spec-aware bot.
2. Change one variable, run it paired on seeds 1 to 16, and add a random-policy arm.
3. Accept only if all targets hold.
4. A difference of 1 or 2 wins in 16 is noise (T8, and `docs/BALANCE.md` saw the same). Confirm a borderline result on 64 seeds before merging.

## 10. Risks and failures (T4, T10)

| Risk                                                          | Likelihood | Impact | Fallback                                                                                                                                                              |
| ------------------------------------------------------------- | ---------- | ------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Spell drag fights pan or pinch (T4)                           | Medium     | High   | A drag counts only if it starts on a tray button. A second finger cancels the cast. A tap-spell-then-tap-cell mode is also always available.                         |
| Blot taps feel like a chore in sustained play (T4, T10)       | Medium     | Medium | Blots also run out by themselves. Keep a floor on blot frequency in content and tune it with the attention gap (too many commands is also a failure).                |
| Mending trivialises losses or becomes the only spend          | Medium     | Medium | A steep price per use and a cap. If it dominates the sweeps, limit it to between waves.                                                                               |
| Bought Ink turns spells into "money wins"                     | Medium     | Medium | The price rises with each purchase, and each spell keeps its own cooldown.                                                                                            |
| The bot cannot aim spells well, so measurements understate them | High     | Medium | A density heuristic (the road cell with the most foes in radius). Report the smart-minus-random delta, and check by hand in owner play.                               |
| Flag-off hashes drift because of new state fields             | Medium     | High   | The snapshot writer gates the fields, and CI runs a byte-identical check with every flag off.                                                                         |
| A solved strategy (T10)                                       | Low        | Medium | Track policy spread, and tune with the bot (T10's unverified roguelike case went from 2/3 to 1/3 this way).                                                          |
| The surplus was a bot artifact                                | Medium     | Low    | Ticket 1 measures first. Scale the sinks down if so.                                                                                                                  |

## 11. Recommendation

**Top pick: Toolbox Tray spells with Ink bought for Buttons, plus Heartstone Mending.**

- Spells and Mending tie at 33. Spells add in-wave decisions every cooldown, and both absorb Buttons.
- Spells are already Phase 7 item 6, so the tie-break favours them. Mending is the S-size sink that ships first.
- Ink Blots scores highest (34) but absorbs no Buttons, so it enters as the pressure-foe ticket.

**Runner-up: the Workbench Draft, if the owner accepts it in the GDD's tone.**

- The matrix ties it with targeting priorities, a new socket and tap-to-collect scraps.
- Targeting priorities are cheap and in the GDD, but they add little density. They stay as a small follow-up, not an alternative.
- The Draft is the one candidate in that tie that adds run-shaping decisions at a scope we can afford.

**Deferred:**

| Item                   | Why it waits                                        |
| ---------------------- | --------------------------------------------------- |
| The hero               | L-size art and a skinned model, Phase 6             |
| Aimed tier-4 actives   | Revisit once spell aiming exists, and reuse its code |
| Cut a new socket       | Backup sink if Mending and Ink fail                 |
| Tap-to-collect scraps  | A spells v2 item                                    |
| Messenger Crow orders  | Only with rewards that are not Buttons              |
| Targeting priorities   | A small follow-up ticket                            |

**Cut:**

| Item                                    | Why it is cut                         |
| --------------------------------------- | ------------------------------------- |
| Paperclip Grunts                        | Would be a sixth foe                  |
| Winding overdrive and swipe harvesting  | Gesture conflicts with pan            |
| Ink seepage and bridges                 | Need a branching route                |
| Splitters, folders, desk fan            | Low density and new models            |
| Masterwork tier                         | Contradicts the GDD                   |
| Shred a tower                           | Low density                           |

### Tickets (Phase 7, in this order)

1. **[Phase 7] Measure the late game with a spec-aware bot** (`phase-7`, `sim`)
   - The bot chooses specs and activates abilities when they are ready. Some profiles call waves early. A random-legal policy arm is added.
   - `balance_run.gd` reports the attention gap (with and without activate-on-ready), unspent Buttons per wave and wins per profile. It accepts 64 seeds.
   - Done when:
     - GUT tests pin the metric on a fixed seed.
     - The goldens are regenerated, a reviewed change because the bot itself changed.
     - The baseline numbers are recorded in `docs/BALANCE.md`.
2. **[Phase 7] Add Heartstone Mending and content feature flags** (`phase-7`, `sim`)
   - Adds `content/features.gd`, `MEND_HEARTSTONE` with a price list that rises per use, and the snapshot rule that gates a feature's fields.
   - Done when:
     - GUT tests cover the price, the cap, refusals and refusal with the flag off.
     - A golden with the flag on is added.
     - `replays.json` is byte-identical with the flag off.
     - The bot uses Mending, and the sweep shows the win band and the unspent-Buttons change.
3. **[Phase 7] Add Crafting Energy, three spells and Ink bought with Buttons** (`phase-7`, `sim`)
   - Adds `CAST_SPELL(spell, col, row)` and `BUY_INK`. The glue trap reuses zones. Thumbtacks use a fixed pattern. The Eraser reuses the armor strip.
   - Done when:
     - GUT tests cover each spell, energy regeneration, the Ink price and refusals.
     - A golden with the flag on is added, and the old goldens are unchanged with it off.
     - The bot aims by foe density.
     - The metrics meet section 9's targets, or the PR says why not.
4. **[Phase 7] Build the Toolbox Tray with drag and two-tap casting** (`phase-7`, `ui`)
   - Adds the bottom-right tray, a ground decal and press-time arbitration against pan.
   - Done when:
     - Tests cover the extracted arbitration logic.
     - Targets are at least 44 px.
     - The Playwright smoke test is green.
     - There is a phone check on a real device.
5. **[Phase 7] Let the Ink Shaman blot towers** (`phase-7`, `sim`)
   - Adds the blot timer, the deterministic target and `CLEAR_BLOT`.
   - Done when:
     - GUT tests cover the blot, the clear, the expiry and the Shaman's death.
     - A golden with the flag on is added, and the old goldens are unchanged with it off.
     - The bot clears blots.
     - The attention gap is measured.
6. **[Phase 7] Retune the wave curve for waves 8 to 20** (`phase-7`, `content`)
   - Done when:
     - Section 9 is met on 16 seeds, and borderline profiles are confirmed on 64.
     - GUT tests cover the constants.
     - The goldens are regenerated as a reviewed balance change.

### GDD and plan changes

- **GDD section 5:** the Ink Shaman also blots towers.
- **GDD section 6:** Ink can be bought with Buttons, and Mending is added. Note that the GDD describes the spell drag but not a two-tap mode.
- **Plan, Phase 7:** add the bot-metrics item and the features flag file. Add to the gate: the attention-gap and unspent-Buttons targets, and the byte-identical check with flags off.
- **Plan, Backlog:** record the Draft, a new socket and Masterwork as deferred.

### Open questions for the owner

1. **Is a roguelike draft acceptable in the GDD's tone?** Default: not now. Revisit after the spells, framed as "Workbench blueprints".
2. **Should spells and actives aim at a tapped cell?** Default: spells yes, since the GDD already says drag to a decal. Tier-4 actives stay self-aimed (the 2026-10-16 decision), to be revisited once spell aiming exists.
3. **Should the hero come before Phase 6 art?** Default: no. The hero needs a skinned model, and the spells cover the need for in-wave agency.
4. **Does the second spawn source at wave 11 change the no-branching rule?** Default: no. The 2026-10-16 decision (#268) allows merging feeders only; detours, branching and drawbridges stay dropped, and no further sources are added in this RFC.
5. **Is any foe beyond the GDD's five allowed?** Default: no. Pressure comes from new behaviour on the Ink Shaman.
6. **May Buttons buy Heartstone health, given that Phase 8 pays Golden Staples from remaining health?** Default: yes, with a rising price. Decide in Phase 8 whether mended health counts towards Staples.

## Sources and confidence

- **Weak: snippets or secondary sources only.**
  - All BTD6 numbers: cooldowns, Energizer, Paragon power, Bank caps, reward decay, round RBE (T1, T3, T7).
  - Kingdom Rush cooldowns: a conflicting Hellfire value and an unverified early-call bonus (T1, T3).
  - The Slay the Spire talk, via a summary (T2).
  - Hoober grip shares; the Apple 44 pt figure is unverified (T4).
  - The Age of Empires command scheduling (T5).
  - Every T10 anecdote, two of them unverified.
- **Researcher or author proposals with no source.**
  - T5: the flag-off rule and the bot as a pure function.
  - T7: all target numbers.
  - T8: the attention-gap and decision-density metrics.
  - This RFC: every score in section 4.
- **Moderate.**
  - The Material and WCAG target sizes and the touch-accuracy studies (T4).
  - The general draft conventions (T2).
- **From the repo, high confidence.**
  - Spec costs, the refund, the early-call formula, the stream ids and the golden format.
  - That the bot is spec-blind and never calls early.
  - That no content flag exists yet.
