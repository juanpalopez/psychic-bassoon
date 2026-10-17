## Plays the models' clips like stop-motion: the clips are keyed at 12 frames a second
## (`assets-src/papercraft/towers_export.py`), and stepping between those keys instead of
## blending them is what makes the papercraft look hand-animated while the camera moves
## smoothly.
class_name StopMotion
extends RefCounted


## The first AnimationPlayer under `node`, or null.
static func player_of(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var found := player_of(child)
		if found != null:
			return found
	return null


## Makes every track of `player`'s clips step, and the clips named in `loops` loop.
static func prepare(player: AnimationPlayer, loops: Array[String]) -> void:
	for clip in player.get_animation_list():
		var animation := player.get_animation(clip)
		for track in animation.get_track_count():
			animation.track_set_interpolation_type(track, Animation.INTERPOLATION_NEAREST)
		animation.loop_mode = Animation.LOOP_LINEAR if loops.has(clip) else Animation.LOOP_NONE


## The first node under `node` whose name ends with `suffix` (a model's "_Head"), or null.
static func part(node: Node, suffix: String) -> Node3D:
	if node is Node3D and String(node.name).ends_with(suffix):
		return node
	for child in node.get_children():
		var found := part(child, suffix)
		if found != null:
			return found
	return null


## Swaps the imported materials of every mesh under `node` for the papercraft looks.
static func dress(node: Node) -> void:
	if node is MeshInstance3D:
		var instance := node as MeshInstance3D
		instance.mesh = PaperLook.dress(instance.mesh)
	for child in node.get_children():
		dress(child)


## Lets only the parts whose name ends with `caster` cast a shadow ("" for none), so a model's
## moving parts cost no extra draw calls in the shadow map.
static func cast_shadows(node: Node, caster: String) -> void:
	if node is GeometryInstance3D:
		var on := caster != "" and String(node.name).ends_with(caster)
		(node as GeometryInstance3D).cast_shadow = (
			GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			if on
			else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		)
	for child in node.get_children():
		cast_shadows(child, caster)
