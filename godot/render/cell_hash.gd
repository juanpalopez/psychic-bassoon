## A number from 0 to 1 that depends only on its arguments, so a board's random-looking
## choices (decor, tape wobble) come out the same for the same cell and seed, with no random
## stream in the render code.
class_name CellHash
extends RefCounted


static func of(a: int, b: int, c: int, salt: int) -> float:
	var h := (a * 73856093) ^ (b * 19349663) ^ (c * 83492791) ^ (salt * 2654435761)
	h = (h ^ (h >> 13)) * 1274126177
	h = h ^ (h >> 16)
	return float(h & 0xFFFFFF) / 16777216.0
