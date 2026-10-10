## A tower on a plot. `level` counts from 0 (level 1) to 2 (level 3).
class_name Tower
extends RefCounted

var id: int = 0
## A tower id from `content/towers.gd`, such as "ballista".
var type: String = ""
var level: int = 0
var col: int = 0
var row: int = 0
## Gold spent so far; a sale refunds a share of it.
var invested: int = 0
## Seconds until it may fire again. Runs below zero while idle.
var cooldown: float = 0.0
