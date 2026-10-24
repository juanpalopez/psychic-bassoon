## Reach measured to the road band's edge (#446, option B, owner 2026-10-22). Tools only: the
## sim measures reach to the centre line until #446's combat seam lands.
extends RefCounted


## Half of a road band's width, in cells: how far a foe on the band can stand from the centre line.
static func half_band(width: float) -> float:
	return maxf(width, 0.0) * 0.5


## The reach from a tower to a centre-line point at which a foe on the band is in reach: the
## centre-line reach plus half the band, so `centre distance - half_band <= reach`.
static func edge_reach(reach: float, width: float) -> float:
	return reach + half_band(width)
