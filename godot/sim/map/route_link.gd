## How a branch of a forked road lines up with the main road (#481): the stretch at the start
## where both are the same line, the branch's own stretch where they are not, and the stretch
## after the merge where they are the same line again, `offset` further along the branch.
## Distances are in cells walked along a route. A pure value, built once per game.
class_name RouteLink
extends RefCounted

## The branch and the main road are one line up to this distance (the same on both).
var head: float = 0.0
## From this distance along the branch on, it is the main road's line again.
var tail_route: float = 0.0
## The same point along the main road.
var tail_main: float = 0.0


## The link of `fork`'s branch route. On curved routes the curves near the fork and the merge
## differ from the main road's for `JOIN_SETTLE_CELLS` cells, so the shared stretches start
## and end that many cells further from the branch's own, like the feeder's join offset.
static func of(main: Route, branch: Route, fork: GameMap.Fork) -> RouteLink:
	var settle := Route.JOIN_SETTLE_CELLS if branch.curved else 0
	var link := RouteLink.new()
	link.head = main.cell_distance(maxi(fork.fork_index - settle, 0))
	var merge_on_main := mini(fork.merge_index + settle, main.cell_points.size() - 1)
	var merge_on_branch := mini(
		fork.fork_index + 1 + fork.branch_length + settle, branch.cell_points.size() - 1
	)
	link.tail_main = main.cell_distance(merge_on_main)
	link.tail_route = branch.cell_distance(merge_on_branch)
	return link


## How much further along the branch a point of the shared tail is than along the main road.
func offset() -> float:
	return tail_route - tail_main


## The distance along the main road of a point `distance` along the branch, or -1 on the
## branch's own stretch.
func to_main(distance: float) -> float:
	if distance <= head:
		return distance
	if distance < tail_route:
		return -1.0
	return distance - offset()


## The distance along the branch of a point `along` the main road, or -1 on the main road's
## stretch beside the branch's own.
func from_main(along: float) -> float:
	if along <= head:
		return along
	if along < tail_main:
		return -1.0
	return along + offset()
