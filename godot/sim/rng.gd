## Seeded pseudo-random numbers for the simulation (mulberry32).
##
## All randomness in the sim goes through this class, never `randf` or
## `randi`. The same seed gives the same sequence on every machine and equals
## the TypeScript sim's, so a run replays from its seed and its commands.
##
## Use one generator per subsystem, made with `Rng.derive(seed, stream)` and
## the ids in `Streams`. The state is kept in [0, 2^32): every `*`, `+` and
## `^` is masked, which replaces JavaScript's `Math.imul` and `>>>`. Products
## of two 32-bit values wrap in GDScript's 64-bit integers, and the low 32
## bits stay correct.
class_name Rng
extends RefCounted

const MASK := 0xFFFFFFFF
const STEP := 0x6d2b79f5
const UINT32_RANGE := 4294967296.0
const GOLDEN_RATIO_32 := 0x9e3779b9
const MIX_A := 0x85ebca6b
const MIX_B := 0xc2b2ae35

## Generator state, an integer in [0, 2^32). Plain data, so it survives JSON.
var state: int = 0


## Creates a generator from an integer seed, reduced to 32 bits.
static func create(seed: int) -> Rng:
	var rng := Rng.new()
	rng.state = seed & MASK
	return rng


## Creates an independent generator for one subsystem. The same seed and
## stream always give the same generator. `stream` must not be negative.
static func derive(seed: int, stream: int) -> Rng:
	assert(stream >= 0, "stream must not be negative")
	# murmur3 finalizer over (seed + stream * golden ratio): nearby seeds and
	# streams land far apart, so their sequences do not overlap
	var hash: int = ((seed & MASK) + _imul(stream + 1, GOLDEN_RATIO_32)) & MASK
	hash ^= hash >> 16
	hash = _imul(hash, MIX_A)
	hash ^= hash >> 13
	hash = _imul(hash, MIX_B)
	hash ^= hash >> 16
	var rng := Rng.new()
	rng.state = hash & MASK
	return rng


## Copies the generator; the copy continues the same sequence independently.
func clone() -> Rng:
	var copy := Rng.new()
	copy.state = state
	return copy


## Next float in [0, 1).
func next_float() -> float:
	state = (state + STEP) & MASK
	var t: int = state
	t = _imul(t ^ (t >> 15), t | 1)
	t ^= (t + _imul(t ^ (t >> 7), t | 61)) & MASK
	return float((t ^ (t >> 14)) & MASK) / UINT32_RANGE


## Next integer in [0, max_exclusive). `max_exclusive` is from 1 to 2^32.
func next_int(max_exclusive: int) -> int:
	assert(max_exclusive >= 1 and max_exclusive <= 4294967296, "bound out of range")
	return int(floor(next_float() * float(max_exclusive)))


## Next float in [min_value, max_value). Needs min_value < max_value.
func next_range(min_value: float, max_value: float) -> float:
	assert(min_value < max_value, "range needs min < max")
	return min_value + next_float() * (max_value - min_value)


## A random item from a non-empty array.
func pick(items: Array) -> Variant:
	assert(not items.is_empty(), "cannot pick from an empty array")
	return items[next_int(items.size())]


## 32-bit integer multiply (JavaScript's Math.imul), result in [0, 2^32).
static func _imul(a: int, b: int) -> int:
	return (a * b) & MASK
