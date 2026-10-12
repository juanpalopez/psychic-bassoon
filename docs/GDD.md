# Papercraft Kingdom Defense: Game Design Document (GDD)

> **Source:** the owner's Google Doc "Game Design Document - Papercraft Kingdom Defense" (first snapshot 2026-10-11; updated 2026-10-12 with the 22 x 16 map, 2x2 sockets, the Heartstone, the Kitchen Mess Tent, the Camp Cook, the Messenger Crow and an audio section). The Google Doc is the living version; this file is the copy the plan and the code are checked against. Where the GDD and `docs/PLAN.md` disagree, the plan lists the open question under "Gaps in the GDD". The GDD gives few numbers; balance numbers live in `godot/content` and are tuned by headless runs.

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
4. **Wave rewards and permanent tech tree:** earn Golden Staples based on remaining Heartstone health. Spend staples in the workshop menu to upgrade permanent crafting skills, unlock base stats, and purchase new origami blueprints.

### Touch ergonomics and interaction model

Designed specifically for handheld screens, the interaction layer prioritizes touch accuracy and comfort across varying screen aspect ratios:

- **Radial context menus:** tapping a socket or tower opens a minimum 48x48 pt target radial wheel offset above the touch point, ensuring the player's finger never obstructs active selection icons.
- **Camera navigation:**
  - One-finger pan: smooth panning across the cutting mat table with soft edge rubber-banding bounds.
  - Two-finger pinch-to-zoom: smooth elevation zoom bounded between 30° and 65° isometric view angles.
- **Global spell activation:** drag-and-drop mechanics from a persistent bottom-right "Toolbox Tray". Spells display live projection decals on the map ground layer before releasing touch to cast.
- **Screen-space non-grid HUD:** persistent gameplay metrics (Heartstone HP, Buttons currency, PVA Ink) live on a 2D `CanvasLayer` overlay so they never occupy world grid cells. A bottom-docked toolbox tray holds the spells, and a diegetic Messenger Crow (an origami courier on a spring wire, see section 6) delivers event notifications.

## 3. Map system and level design

### Grid architecture

Maps are strictly standardized to a **22-column by 16-row landscape grid (352 cells)**, built from modular 1m x 1m GridMap tiles within Godot 4. The board is surrounded by an out-of-bounds diorama skirt that represents the rest of the craft-room desk. Terrain is categorized by distinct physical elevations:

- **Level 0 (cutting mat table):** base surface. Enemies move along marked lanes 1 to 2 cells wide.
- **Level 1 (glued cardboard rise):** a low layer of double-walled corrugated cardboard, +1.0 m high.
- **Level 2 (elevated tiered cliffs):** high cliffs of stacked paperboard blocks, +2.0 m high. Towers placed on Level 2 receive a +15% Range Bonus and bypass low-terrain Line of Sight (LOS) blockades.

### Sockets, footprints and objectives

- **Sockets and footprints:** tower sockets occupy a standard 2x2 cell footprint (2.0 m x 2.0 m) with a pre-etched circular outline that flashes white when tapped. Towers have exaggerated vertical heights (3 m to 6 m) for readability. There are 12 to 22 sockets per map; a socket turns to folded cardstock once built on.
- **Heartstone objective:** at the end of the enemy lane, on a 2x2 to 3x3 cell footprint, an illuminated origami heart crystal is the core objective. Its health is the player's health.

### Environmental hazards and dynamic paths

Maps include interactive craft-room hazards along the enemy paths: blue metallic-foil rivers crossed by wooden popsicle-stick bridges (a foe knocked into the water is slowed 50%), sticky tape strips that act as single-use traps, and sticky PVA glue puddles.

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
   ┌─ The Spool Guard ┬─ Crossbow Ballista
   │                  └─ Paper-Plane Aviary
   ├─ The Guard Tent  ┬─ Cardboard Knights
   │                  └─ Scissor Rogues
Towers ┤
   ├─ The Prism Spire ┬─ Cryo-Origami Spire
   │                  └─ Blot Singularity
   ├─ The Thimble     ┬─ Glitter Cannon
   │  Mortar          └─ Sticky Glue Mortar
   └─ The Kitchen     ┬─ Iron Rations
      Mess Tent       └─ Gourmet Frenzy
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

#### 5. The Kitchen Mess Tent (barracks support)

Base unit: a 2x2 footprint cardboard mess hall that generates a base aura, Hearty Stew, boosting neighboring unit attack speed and health regeneration.

- **Spec A: Iron Rations**
  - Active: Fortified Feast. Instantly grants a heavy shield barrier to all friendly troops within aura range for 10 seconds.
  - Passive: Hardtack Toughness. Increases max health of nearby barracks defenders by +30%.
- **Spec B: Gourmet Frenzy**
  - Active: Boiling Broth Splash. Splashes scalding stew onto enemy paths, dealing area fire damage and applying a movement speed penalty.
  - Passive: Sugar Rush. Buffs movement and attack speed of friendly hero and barracks units within range by +25%.

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

### Hero unit 2: the Camp Cook

A specialized barracks support hero crafted from folded recipe paper and a tin foil ladle.

- **Role:** area-buff support unit and defensive crowd-controller.
- **Ability 1 (passive), Rations and Morale:** nearby troops heal 2% HP per second and gain +10% resistance to all damage types.
- **Ability 2 (active), Boiling Stew Splash:** throws a ladle of boiling paper-pulp soup, burning enemies in a target area and reducing their move speed by 40% for 5 s.

### Diegetic alert messenger: the Messenger Crow

A non-combat origami crow attached to a spring wire that flies across the screen layer to deliver receipt-paper scrolls containing wave alerts, secret objectives, and urgent craft warnings.

### Global crafting spells

Activated from the bottom tray by spending Crafting Energy generated during wave combat.

| PVA Glue Trap | Falling Thumbtacks | The Crafter's Eraser |
| --- | --- | --- |
| Slows ground paths 60% for 8 seconds | Physical hazard damaging area | Deletes non-boss armor completely |

1. **PVA Glue Trap:** pours a line of white glue across a path segment. Enemies entering the zone suffer a 60% movement speed penalty for 8 seconds.
2. **Falling Thumbtacks:** drops a handful of brass thumbtacks onto a 2x2 grid area. Deals physical damage and causes light enemies to stumble/pause for 0.5 s per tack stepped on.
3. **The Crafter's Eraser:** a targeted rubber eraser tool that wipes away non-boss enemy shields, armor plating, and positive magical buffs in a targeted radius.

## 7. Audio architecture: music and diegetic SFX

### Foley philosophy and sound matrix

All sound effects use a physical, tactile craft-room foley palette to reinforce the miniature physical world:

- **Rubber band twangs:** Ballista fires and catapult releases.
- **Thimble clinks and metal snaps:** artillery impacts and armor hits.
- **Glass rim chimes:** Prism Spire attacks and magical spell activations.
- **Scissor snaps and paper tears:** slash attacks, creep deaths, and cardstock construction.
- **Stamp thuds:** heavy boss footsteps and UI button confirmations.

### Adaptive soundtrack architecture

The interactive music system switches stem layers by the intensity of the game state:

- **Tier 1, planning stem:** light acoustic guitar, marimba, and soft paper rustles during build phases.
- **Tier 2, wave stem:** adds rhythmic cardboard percussion, pizzicato strings, and energetic woodwinds during active combat.
- **Tier 3, boss and urgent stem:** brass fanfares, intense wooden percussion, and low cello swells during boss spawns or low Heartstone health.

## 8. Godot 4 technical architecture and asset pipeline

### Scene and node architecture

The game framework uses an event-driven design to ensure optimal performance on mobile hardware:

```
Main Scene (Node3D)
├── GameManager (Node) -------- Handles state machine, wave orchestration, and currency
├── AudioManager (Node) ------- Orchestrates 3-tier adaptive audio stems & diegetic foley SFX
├── BoardGrid (GridMap) ------- Manages 22x16 modular terrain tiles & height levels
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
