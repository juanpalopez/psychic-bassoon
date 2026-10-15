## A tower on a plot. `level` counts from 0 (level 1) to 2 (level 3).
class_name Tower
extends RefCounted

var id: int = 0
## A tower id from `content/towers.gd`, such as "spoolGuard".
var type: String = ""
var level: int = 0
var col: int = 0
var row: int = 0
## Buttons spent so far; a sale refunds a share of it.
var invested: int = 0
## Seconds until it may fire again; 0 while it waits for a target.
var cooldown: float = 0.0
## A beam tower's locked foe (its id), or -1 when it has none. Render reads it to
## draw the beam; other towers keep -1.
var target_id: int = -1
## The tier 4 spec id chosen at the top level, or "" before.
var spec: String = ""
## Seconds until the spec's active may be used again; 0 when it is ready.
var ability_cooldown: float = 0.0
