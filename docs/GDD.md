# Papercraft Kingdom Defense: Game Design Document (GDD)

> **Source:** the owner's Google Doc "Game Design Document - Papercraft Kingdom Defense" (snapshot taken 2026-10-11 from its plain-text export). The Google Doc is the living version; this file is the copy the plan and the code are checked against. Where the GDD and `docs/PLAN.md` disagree, the plan lists the open question under "Gaps in the GDD". The GDD gives few numbers; balance numbers live in `godot/content` and are tuned by headless runs.

## 1. Executive summary and narrative lore

### High concept

Papercraft Kingdom Defense is a tactile, isometric 3D tower defense experience designed natively for mobile and tablet touchscreens, built within the Godot 4 engine. Featuring a distinct stop-motion physical aesthetic, players construct defenses out of recycled office supplies, cardstock, and origami to turn back waves of corrupted stationery.

### Setting and lore: the War of the Cutting Mat

In a forgotten corner of an old craft room, an abandoned green self-healing cutting mat harbors a thriving miniature civilization. Peace reigns among the recycled paper strips and cardboard cutouts until The Blot strikes: a bottle of corrupted, magical purple India ink tips over in the high shelves above.

As dark ink seeps into the paper fiber, it twists peaceful scraps into jagged, aggressive monsters intent on shredding everything into confetti. Players take on the role of The Grand Crafter, using legendary craft artifacts (scissors, glue guns, tape rolls) to guide origami defenders and erect corrugated bastions against the ink-born tide.

## 2. Core game loop and touch ergonomics

### The game loop

The primary gameplay loop balances tactical preparation with real-time micro-management across four distinct phases:

1. **Scout and build phase:** review wave paths, inspect enemy composition icons, and spend starting Buttons (currency) to place base towers on pre-etched sockets.
2. **Engage wave:** trigger the wave early for bonus resource income or allow the timer to expire.
3. **Combat and resource management:** manage tower targeting priorities, deploy hero movement commands, harvest defeated enemy drop-scraps, and cast Global Crafting Spells using regenerable PVA Ink/Energy.
4. **Wave rewards and permanent tech tree:** earn Golden Staples based on remaining kingdom health. Spend staples in the workshop menu to upgrade permanent crafting skills, unlock base stats, and purchase new origami blueprints.

### Touch ergonomics and interaction model

Designed specifically for handheld screens, the interaction layer prioritizes touch accuracy and comfort across varying screen aspect ratios:

- **Radial context menus:** tapping a socket or tower opens a minimum 48x48 pt target radial wheel offset above the touch point, ensuring the player's finger never obstructs active selection icons.
- **Camera navigation:**
  - One-finger pan: smooth panning across the cutting mat table with soft edge rubber-banding bounds.
  - Two-finger pinch-to-zoom: smooth elevation zoom bounded between 30° and 65° isometric view angles.
- **Global spell activation:** drag-and-drop mechanics from a persistent bottom-right "Toolbox Tray". Spells display live projection decals on the map ground layer before releasing touch to cast.

## 3. Map system and level design

### Grid architecture

Maps are constructed using modular 1m x 1m GridMap tiles within Godot 4. Terrain is categorized by distinct physical elevations that affect combat mechanics:

- **Level 0 (cutting mat table):** standard ground path level. Enemies traverse along marked gridlines.
- **Level 1 (glued cardboard rise):** low elevation layer constructed from double-walled corrugated cardboard. Grants ground units blocking choke points.
- **Level 2 (elevated tiered cliffs):** high points made from stacked paperboard blocks. Towers placed on Level 2 automatically receive a +15% Range Bonus and bypass low-terrain Line of Sight (LOS) blockades.

### Pathing systems

Pathfinding utilizes Godot Path3D splines with custom logic for dynamic environmental hazards:

- **Branching choke points:** maps feature split paths with toggleable cardboard drawbridges operated by nearby mechanical levers.
- **Environmental obstacles:** foil paper rivers slow enemy movement by 25%, while sticky tape strips act as single-use slowing zones.

### Sockets and placement

To eliminate placement frustration on small mobile screens, free-form building is replaced by pre-etched circular sockets (12 to 22 per map). Sockets flash subtle white pencil-outlines when selected and visually alter their texture to folded cardstock once built upon.

## 4. Tower archetypes and level upgrade system

### Progression model

Every tower follows a strict 4-tier structural path:

- **Tier 1 to 3:** linear statistical upgrades (damage, range, fire rate).
- **Tier 4 specialization split:** at Tier 3, towers split into two distinct endgame specializations. Each specialization provides 1 Active Ability and 1 Passive Ability.

```
[Tier 1 Base] -> [Tier 2 Upgraded] -> [Tier 3 Advanced] -> [Tier 4 Spec A]
                                                        \-> [Tier 4 Spec B]
```

### Core towers and specializations

```
                  ┌─ Crossbow Ballista
   ┌─ The Spool Guard ┴─ Paper-Plane Aviary
   ├─ The Guard Tent  ┬─ Cardboard Knights
Towers ┤             └─ Scissor Rogues
   ├─ The Prism Spire ┬─ Cryo-Origami Spire
   │                  └─ Blot Singularity
   └─ The Thimble     ┬─ Glitter Cannon
      Mortar          └─ Sticky Glue Mortar
```

#### 1. The Spool Guard (archer tower)

Base unit: a wooden thread spool mounting a toothpick ballista firing sharp paper-strip darts at fast single targets.

- **Spec A: Crossbow Ballista**
  - Active: Heavy Skewer. Fires a heavy bolt piercing up to 5 aligned enemies, inflicting a Bleed status.
  - Passive: Armor Piercing. Ignores 40% of armored enemy defensive values.
- **Spec B: Paper-Plane Aviary**
  - Active: Squadron Launch. Deploys 3 origami paper planes that patrol the nearby path, dropping dart bombs on targets.
  - Passive: High Recon. Extends the sight range of all adjacent towers by 20%.

#### 2. The Guard Tent (barracks)

Base unit: a folded origami tent that spawns 2 paper-craft guards to block pathing.

- **Spec A: Cardboard Knights**
  - Active: Shield Wall. Grants deployed units double armor and complete knockback immunity for 8 seconds.
  - Passive: Corrugated Plating. Guards reflect 15% of incoming physical melee damage back to attackers.
- **Spec B: Scissor Rogues**
  - Active: Precision Snipe. A dual-bladed guard leaps forward, dealing massive single-target true damage to a target unit.
  - Passive: Paper Cuts. Attacks reduce target movement speed by 10% per hit (stacks up to 3 times).

#### 3. The Prism Spire (mage tower)

Base unit: a rolled construction paper tower topped with a glass marble prism that channels focused light rays.

- **Spec A: Cryo-Origami Spire**
  - Active: Flash Freeze. Emits a cold burst that freezes all enemies within range in blocks of paraffin wax for 3 seconds.
  - Passive: Frostbite. Slowed enemies take +20% extra damage from all physical towers.
- **Spec B: Blot Singularity**
  - Active: Ink Vortex. Creates a gravity well that pulls nearby lightweight enemies toward its center.
  - Passive: Corrosive Light. Beam attacks strip enemy armor plating by 2% per second of continuous fire.

#### 4. The Thimble Mortar (artillery)

Base unit: a heavy metal thimble loaded with matchstick powder, launching splash-damage paper pellets.

- **Spec A: Glitter Cannon**
  - Active: Confetti Burst. Fires a wide-area shell that blinds enemies, causing them to miss 40% of their melee attacks.
  - Passive: Shrapnel Spread. Increases total splash radius by 35%.
- **Spec B: Sticky Glue Mortar**
  - Active: PVA Deluge. Coats the target area in heavy PVA glue, reducing enemy movement speed by 70% for 6 seconds.
  - Passive: Lingering Residue. Mortar shells leave burning/slowing pools on the track for 4 seconds after impact.

## 5. Enemy roster and attributes

| Category | Unit name | Visual material | Gameplay attributes and counters |
| --- | --- | --- | --- |
| Swarm | Scrap Goblin | Shredded newsprint | Fast movement speed, low health. Weak against splash damage (Thimble Mortar). |
| Flying | Razor Moth | Tissue paper and wire | Bypasses ground blockades and paths. Countered by anti-air (Spool Guard / Aviary). |
| Armored | Corrugated Orc | Multi-layer cardboard | Extremely high armor, slow movement speed. Requires armor-stripping or magic (Prism Spire). |
| Support | Ink Shaman | Blot-stained filter paper | Heals nearby corrupted units and grants speed buffs. Must be prioritized by targeted skills. |
| Boss | Cardboard Golem | Stacked shipping box | Massive health pool; spawns Scrap Goblins upon destruction. Requires hero engagement and spells. |

## 6. Player skills, spells and hero system

### Hero unit: the Knight of Cardboard

A movable, persistent hero unit crafted from heavy cardstock and foil armor.

- **Role:** primary frontline blocker and tactical dynamic responder.
- **Ability 1 (passive), Rally Cry:** allied units within a 3-meter radius gain +15% attack speed and +10% health regeneration.
- **Ability 2 (active), Blade Whirl:** the Knight spins with a foil sword, dealing heavy physical area-of-effect damage to all adjacent ground units (15 s cooldown).

### Global crafting spells

Activated from the bottom tray by spending Crafting Energy generated during wave combat.

| PVA Glue Trap | Falling Thumbtacks | The Crafter's Eraser |
| --- | --- | --- |
| Slows ground paths 60% for 8 seconds | Physical hazard damaging area | Deletes non-boss armor completely |

1. **PVA Glue Trap:** pours a line of white glue across a path segment. Enemies entering the zone suffer a 60% movement speed penalty for 8 seconds.
2. **Falling Thumbtacks:** drops a handful of brass thumbtacks onto a 2x2 grid area. Deals physical damage and causes light enemies to stumble/pause for 0.5 s per tack stepped on.
3. **The Crafter's Eraser:** a targeted rubber eraser tool that wipes away non-boss enemy shields, armor plating, and positive magical buffs in a targeted radius.

## 7. Godot 4 technical architecture and asset pipeline

### Scene and node architecture

The game framework uses an event-driven design to ensure optimal performance on mobile hardware:

```
Main Scene (Node3D)
├── GameManager (Node) -------- Handles state machine, wave orchestration, and currency
├── BoardGrid (GridMap) ------- Manages 1m x 1m modular terrain tiles & height levels
├── PathController (Node3D) --- Contains Path3D splines & dynamic bridge/route updates
├── TowerSockets (Node3D) ----- Container for individual Socket nodes
│   └── TowerSocket (Area3D) - Manages occupancy state, radial menu triggers, & placement
└── CanvasLayer (UI) ---------- Mobile HUD, Touch Event Dispatcher, & Global Tool Tray
```

### Shaders and materials

To maintain a convincing real-world crafting scale, custom Godot `StandardMaterial3D` settings and custom visual shaders are utilized:

- **Kraft paper and cardboard:** high roughness value (0.85), subtle height maps for corrugated interior layers, and detail normal maps for raw paper fiber textures.
- **Translucency and edge sizing:** subsurface transmission (SSS) enabled on creased paper edges to simulate light passing through thin paper under bright desk lighting.
- **The Blot effects:** custom vertex displacement shader with saturated purple specular channels to render glistening, ink-drenched corrupted surfaces.

### Animation styling: stop-motion puppetry

To emphasize the handmade aesthetic, character and projectile animations avoid continuous interpolation:

- **Stepped keyframing:** animations run at a fixed 12 FPS step rate using Godot's `AnimationPlayer` playback options, giving models an authentic stop-motion / cut-out paper puppetry feel while the engine camera renders at a smooth 60 FPS mobile refresh rate.
