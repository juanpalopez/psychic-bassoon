## Pure helpers of the road-time measurement (#460): order statistics, the layout/strip gate and
## per-region exposure. Tools only; nothing here touches the sim or the game's content.
extends RefCounted

## The gate on the ratio of the layout valley's time under fire to the strip valley's (#460): the
## median within 90 to 110 percent and no seed below 75 percent.
const GATE_MEDIAN_LOW := 0.90
const GATE_MEDIAN_HIGH := 1.10
const GATE_SEED_MIN := 0.75


## True for a speed scale the tool can divide by: above zero.
static func is_valid_scale(scale: float) -> bool:
	return scale > 0.0


## The foe's speed in the tool's arithmetic only: `--speed=` multiplies it, content stays as it is.
static func scaled_speed(base: float, scale: float) -> float:
	return base * scale


## The value at percentile `pct` (0 to 100) of `values`, by the rule the tool always used
## (`sorted[size * pct / 100]`, clamped to the last), or 0 when there are none.
static func percentile(values: Array[float], pct: int) -> float:
	if values.is_empty():
		return 0.0
	var sorted := values.duplicate()
	sorted.sort()
	return sorted[mini(sorted.size() * pct / 100, sorted.size() - 1)]


static func median(values: Array[float]) -> float:
	return percentile(values, 50)


static func minimum(values: Array[float]) -> float:
	if values.is_empty():
		return 0.0
	return values.min()


## Each layout value over the strip valley's median: the per-seed ratios the gate judges.
static func ratios(values: Array[float], strip_median: float) -> Array[float]:
	var out: Array[float] = []
	if strip_median <= 0.0:
		return out
	for v in values:
		out.append(v / strip_median)
	return out


## True when the ratios pass the gate: median in [GATE_MEDIAN_LOW, GATE_MEDIAN_HIGH], every seed
## at least GATE_SEED_MIN. An empty list never passes.
static func gate_passes(ratio_values: Array[float]) -> bool:
	if ratio_values.is_empty():
		return false
	var med := median(ratio_values)
	return (
		med >= GATE_MEDIAN_LOW
		and med <= GATE_MEDIAN_HIGH
		and minimum(ratio_values) >= GATE_SEED_MIN
	)


## The index of the first rect holding the point (cell coordinates, floats), or -1.
static func region_of(rects: Array[Rect2i], x: float, y: float) -> int:
	var cell := Vector2i(int(floor(x)), int(floor(y)))
	for i in rects.size():
		if rects[i].has_point(cell):
			return i
	return -1


## Adds one step of `dt` walked seconds to region `region` (-1 is ignored). It counts as covered
## when at least one level-1 tower reaches the point, and adds `dt` once per tower in reach to the
## socket-seconds. The three arrays are indexed by region.
static func add_step(
	walk: Array[float],
	covered: Array[float],
	exposure: Array[float],
	region: int,
	towers_in_reach: int,
	dt: float
) -> void:
	if region < 0 or region >= walk.size():
		return
	walk[region] += dt
	if towers_in_reach > 0:
		covered[region] += dt
	exposure[region] += dt * float(towers_in_reach)


## Covered over walked seconds of a region; 0 for a region the road never entered.
static func coverage(walk_seconds: float, covered_seconds: float) -> float:
	if walk_seconds <= 0.0:
		return 0.0
	return covered_seconds / walk_seconds
