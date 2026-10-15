## One foe a wave will release, and the pause before the next one.
class_name SpawnOrder
extends RefCounted

## A foe id from `content/foes.gd`, such as "scrapGoblin".
var type: String = ""
## Seconds to wait after this foe.
var gap: float = 0.0
## The route it walks (an index into `GameState.routes`), or -1 to let the game choose.
var route: int = -1


static func of(foe: String, pause: float) -> SpawnOrder:
	var order := SpawnOrder.new()
	order.type = foe
	order.gap = pause
	return order
