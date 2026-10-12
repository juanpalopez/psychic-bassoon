## The aggregate root: the whole game as plain data. Only `Game.tick` mutates
## it, and only after `Game.submit` queued the commands it runs.
class_name GameState
extends RefCounted

var seed: int = 0
var map: GameMap = null
## The main route (`routes[0]`), built once from the map.
var route: Route = null
## Every route from the spawn to the Heartstone; foes pick one.
var routes: Array[Route] = []
var tick_count: int = 0
var buttons: int = 0
var heartstone_health: int = 0
## Number of the wave most recently launched; 0 before the first.
var wave: int = 0
var running: bool = false
var over: bool = false
var towers: Array[Tower] = []
## Foes on the board, in the order they spawned.
var foes: Array[Foe] = []
## Waves still releasing foes.
var spawners: Array[Spawner] = []
## Random stream for wave composition, separate from the map's.
var rng: Rng = null
## Random stream that picks which route each foe takes.
var route_rng: Rng = null
var next_id: int = 0
## Commands waiting for the next tick, in submission order.
var pending: Array[Command] = []
## Events from the last tick only.
var events: Array[GameEvent] = []
