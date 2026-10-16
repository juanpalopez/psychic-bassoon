---
type: decision
date: 2026-10-16
status: accepted
decided-by: Claude (within ticket scope)
links: [#273, #274]
---
# Build tier 4 as content data plus two commands, one tower pair per PR

## Context
The GDD gives each tower two specialisations with a passive and an active. Eight specs, ten statuses and several shapes of active (a line, an area, a zone, a patrol) could turn into eight special cases in the tick loop. An Opus design memo proposed a shape; this entry keeps the parts that bind later PRs.

## Decision
- Specs are data in `godot/content/specs.gd` (`for_tower`, `find`): a `kind` string per passive and active plus its numbers. The sim maps a `kind` to a handler in `godot/sim/specs/specs.gd`; no other file branches on a spec id.
- The player acts through `CHOOSE_SPEC` (level 3 only, once, cost counts as invested so a sale refunds 70 percent) and `ACTIVATE_ABILITY` (no cost, a cooldown, ready when chosen). An active aims itself at the tower's own target, so the command carries only the tower id. A refused activation never starts the cooldown.
- Statuses are typed fields on `Foe` (not a dictionary), so snapshots hash cleanly. The bleed is the first; it deals true damage each tick and follows the slow's rule (stronger replaces weaker).
- No random numbers anywhere in specs: a skewer hits the foes nearest the tower first.
- PR 1 is the framework plus the Crossbow Ballista. Then one PR per pair (Prism Spire, Thimble Mortar, Aviary, Guard Tent, Mess Tent), then the bot and a balance pass. The bot stays spec-blind until then, so the replays only changed by hash in PR 1.

## Alternatives considered
- One generic effect interpreter in content: too much machinery for eight specs.
- Aiming an active with a tapped cell: the replay and bot need a cell choice; added later if play shows a need.

## Readings chosen for the Prism Spire pair (owner may overrule)
- Frostbite applies to physical damage from towers on a slowed or frozen foe that stands inside the Cryo-Origami spire's reach (not board wide); the strongest bonus applies, they do not add up; it is a share of the damage dealt after armor.
- Corrosive Light strips 2 percent of a foe's armor per second the beam burns it, up to 50 percent, and the strip stays on the foe.
- Ink Vortex pulls foes of the target's route inside its radius along their road towards the target's place at 1.2 cells a second for 5 s; heavy foes (the Cardboard Golem), foes a guard holds and flying foes are not pulled.
- A frozen foe does not walk and does not strike a guard; the guard keeps hitting it.

## Consequences
- Open readings for the owner (the GDD is vague): "aligned" is within a width of the line from the tower through its target; Frostbite's scope (inside the spire's reach or board wide); heroes in Sugar Rush; burning pools.
- The Haiku sweep agent will need spec profiles in the bot and a way to run one profile across seeds (PR 7).
