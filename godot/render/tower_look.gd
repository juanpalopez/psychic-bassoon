## How one kind of tower looks, saved as a .tres so it can be tuned in the
## Inspector. It holds nothing about play: costs and stats live in `content/`.
class_name TowerLook
extends Resource

@export var body_colour := Color("cccccc")
@export var pip_colour := Color("ffffff")
## Width and depth of the body, in cells.
@export var foot := 0.6
## Height of a level 1 body; each level adds `height_per_level`.
@export var base_height := 0.9
@export var height_per_level := 0.35
## The owner's greybox model (a glb under `assets/models/towers`) drawn instead of the
## box, and the scale it is drawn at (its own size times this, in cells) at tier 1.
## An empty or missing path leaves the box.
@export var model_path := ""
@export var model_scale := 1.0
