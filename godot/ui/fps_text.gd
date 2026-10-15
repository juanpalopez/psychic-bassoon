## The line the fps overlay shows.
class_name FpsText
extends RefCounted

const THOUSAND := 1000


static func format(fps: int, draw_calls: int, foes: int, primitives: int) -> String:
	return "%d fps  %d draws  %d foes  %dk tris" % [fps, draw_calls, foes, primitives / THOUSAND]
