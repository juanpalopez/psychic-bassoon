## Prints how often a Kitchen Mess Tent can reach a Guard Tent's guards: for each map
## seed 1 to 40 and for every socket as the place of a Guard Tent, whether any other
## socket's block centre lies within a radius of the middle of the guards' post. The
## figures in docs/BALANCE.md (the aura radius) come from this. Run it with:
##
##   godot --headless --path godot -s tools/aura_coverage.gd
extends SceneTree

const RADII: Array[float] = [2.2, 2.8, 3.0, 3.3, 3.6]
const SEEDS := 40


func _init() -> void:
	var hits: Array[int] = []
	hits.resize(RADII.size())
	hits.fill(0)
	var tents := 0
	for map_seed in range(1, SEEDS + 1):
		var fresh := Game.create(map_seed)
		for anchor in fresh.map.sockets:
			var game := Game.create(map_seed)
			game.buttons = 100000
			GameTestKit.run(game, [Command.build("guardTent", anchor.x, anchor.y)])
			var middle := (game.guards[0].post + game.guards[1].post) / 2.0
			var at := game.routes[0].position_at(middle)
			var nearest := INF
			for other in game.map.sockets:
				if other == anchor:
					continue
				var gap := game.map.socket_centre(other).distance_to(Vector2(at.x, at.y))
				nearest = minf(nearest, gap)
			tents += 1
			for i in RADII.size():
				if nearest <= RADII[i]:
					hits[i] += 1
	print(
		(
			"method: every socket of seeds 1 to %d as a Guard Tent; another socket within the radius"
			% SEEDS
		)
	)
	for i in RADII.size():
		print(
			(
				"radius %.1f: %d of %d Guard Tents (%d%%)"
				% [RADII[i], hits[i], tents, int(round(100.0 * float(hits[i]) / float(tents)))]
			)
		)
	quit()
