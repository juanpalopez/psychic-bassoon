# Design: the Guard Tent, blocking and the Kitchen Mess Tent

Status: approved by the owner (2026-10-12), see Decisions below. The GDD gives the shape (section 4, towers 2 and 5; section 6, heroes); it gives no numbers, so the numbers below are mine and start from the three towers and three foes that exist now. Everything marked "interim" is tuned with the scripted bot like the other numbers (`docs/BALANCE.md`).

The owner asked on 2026-10-12 to add both tents ahead of the rest of Phase 7. This document is the design pass that `docs/PLAN.md` asks for before blocking and melee ("a new combat context").

## What the GDD says

- **Guard Tent** (barracks): "a folded origami tent that spawns 2 paper-craft guards to block pathing". Tier-4 specs (Cardboard Knights, Scissor Rogues) are later.
- **Kitchen Mess Tent** (barracks support): "a 2x2 footprint cardboard mess hall that generates a base aura, Hearty Stew, boosting neighboring unit attack speed and health regeneration". Tier-4 specs (Iron Rations, Gourmet Frenzy) are later.
- Both are placed on the same 2x2 sockets as the other towers. The Mess Tent does nothing without guards, so it comes second.

## New rules

### Foes that fight

A foe gets three new numbers in `godot/content/foes.gd`: `attack_damage`, `attack_interval` (seconds) and `blockable` (whether a guard can stop it). A foe's attack grows with the wave like its hp, more gently: `1 + ATTACK_PER_WAVE * (wave - 1)`.

| Foe | Attack damage | Interval (s) | Blockable |
| --- | --- | --- | --- |
| Scrap Goblin | 3 | 0.8 | yes |
| Corrugated Orc | 14 | 1.6 | yes |
| Cardboard Golem | 40 | 2.0 | no (needs the hero and spells, as the GDD says) |

`ATTACK_PER_WAVE` is 0.03 (wave 20: ×1.57). Flying foes (Razor Moth, later) are never blockable.

### Guards

A Guard Tent owns 2 guards. Each guard is a unit with hp, an attack and a **post**: a fixed distance along the route, the point of the road nearest to the tent's block (ties, common where the road bends around a block, go to the point nearer the Heartstone). The two guards stand half a cell apart so a second foe is not blocked by the same body.

- A guard blocks **one** foe at a time: the first blockable foe that reaches its post (foe reaches `post - guard radius - foe radius`). Other foes walk past a busy guard. This keeps the tent a tool for holding the dangerous foe, not a wall that stops a whole swarm, which would break the wave design.
- A blocked foe stops walking and fights the guard; a slow on it keeps running out while it is held. Both attack on their own interval (physical damage; the guard's armor applies, the foe's armor applies to the guard's blows). Towers keep shooting the stopped foe, which is the point: a held orc is a free target for the Thimble Mortar.
- When the guard falls the foe walks on. When the foe falls the guard is free again. A fallen guard comes back at its post after `respawn` seconds (the tent keeps its 2 guards).
- Out of a fight a guard regenerates `regen` hp per second.
- Selling or replacing the tent removes its guards; a blocked foe walks on.

### Guard Tent numbers (interim)

| | Level 1 | Level 2 | Level 3 |
| --- | --- | --- | --- |
| Cost (Buttons) | 70 | 80 | 140 |
| Guard hp | 60 | 100 | 170 |
| Guard armor | 0 | 2 | 4 |
| Guard damage per blow | 4 | 7 | 12 |
| Guard attack interval (s) | 1.0 | 1.0 | 1.0 |
| Reach (cells, shown to the player; the post is simply the nearest road point) | 1.9 | 2.2 | 2.5 |
| Respawn (s) | 12 | 10 | 8 |
| Regen (hp per second) | 1.0 | 1.5 | 2.0 |

Reading: a level-1 guard (60 hp, 4 dps) holds a wave-1 Scrap Goblin (20 hp, about 4.3 dps against it) for 5 seconds and takes about 21 damage, so two guards hold two goblins and fall to the third. Against a Corrugated Orc (armor 6) a physical blow of 4 does the minimum quarter damage, so a guard cannot kill an orc; it holds it. At 14 damage per 1.6 s the orc kills a level-1 guard in about 7 s, a level-3 guard (170 hp, armor 4) in about 20 s. The tent buys time for the towers, it is not a damage dealer. That is the role the GDD gives it.

### Kitchen Mess Tent numbers (interim)

A 2x2 tent with no attack. Its aura reaches `aura` cells from its block's centre; every guard whose **post** is inside it gets the buffs. Two tents' buffs do not stack: the strongest applies.

| | Level 1 | Level 2 | Level 3 |
| --- | --- | --- | --- |
| Cost (Buttons) | 100 | 100 | 160 |
| Aura radius (cells) | 2.2 | 2.5 | 2.8 |
| Guard attack speed bonus | +12% | +18% | +25% |
| Guard regen bonus (hp per second) | +2 | +3 | +4 |

## Sim design

A new bounded context `godot/sim/barracks/` with a small public entry, read by `Game.tick` after the foes have moved and before the towers fire (so a held foe is a target of the same tick):

- `Guard` (plain data: id, tent id, hp, max hp, armor, post distance, cooldown, respawn timer, engaged foe id), `Barracks.step(game)`.
- `Foe` gains `engaged_guard_id`, `attack_cooldown`; `Combat._move_foes` skips a foe that is engaged.
- `GameState.guards` and `Tower.type` for the tent; a tent is a `Tower` with `guards: true` in its content def, so build, upgrade, sell and sockets are unchanged commands.
- New events appended to the end of `GameEvent.Kind`: `GUARD_RAISED`, `GUARD_FELL`, `FOE_ENGAGED`.
- No new random numbers anywhere: posts, blocking and fights are deterministic. Seeds and replays stay valid; only the replay goldens that include a tent (none until the bot builds one) change.

## Plan

1. Foe attacks, guards, blocking and the Guard Tent in the sim and content (tests first, deep review: it changes the tick loop).
2. The bot builds Guard Tents in a new profile; balance run; the post-tent goldens are written.
3. Greybox render and UI: the tent in the build menu and panel, guards drawn on the road with hp bars, an engaged foe stands still.
4. The Kitchen Mess Tent: aura, content, render, balance.

Not in this work: the tier-4 specs and their actives and passives, the Knight and the Camp Cook, flying foes, Ink Shaman.

## Decisions (owner, 2026-10-12)

1. **Blocking:** one foe per guard; other foes walk past a busy guard. No wall.
2. **The Golem** is not blockable by guards (it needs the hero and spells).
3. **Posts:** a tent's two guards stand on the same stretch of road, half a cell apart.

Status: approved. Building follows the plan above.
