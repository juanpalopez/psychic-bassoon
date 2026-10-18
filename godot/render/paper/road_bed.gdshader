// The road bed (#325, docs/art/STYLE.md): packed earth in warm sand with a hint of flagstones,
// a darker worn edge and a paper lip along each side. The mesh gives UV.y across the bed, from
// -1 at one outer edge through 0 in the middle to 1 at the other (the Heartstone's yard gives the
// distance out from its middle, 0 to 1). The flagstones are laid in world space, so the bed and
// the yard share one paving. Nothing reads the screen, so Compatibility, Mobile and Forward+ draw
// it the same; a few mixes and one noise read a pixel.
shader_type spatial;
render_mode cull_disabled;

uniform sampler2D paper_noise : hint_default_white, filter_linear_mipmap, repeat_enable;

group_uniforms road;
// The sand, its worn edge, the joints between flagstones and the lip's outer face, where the bed
// meets the grass. The palette is TerrainPalette (ROAD, ROAD_EDGE, ROAD_JOINT, ROAD_LIP), which
// RoadBedBuilder sets here; nothing is written twice.
uniform vec3 road_light : source_color;
uniform vec3 road_edge : source_color;
uniform vec3 joint_colour : source_color;
uniform vec3 lip_colour : source_color;
// Where across the bed (share of the half width) the wear starts and where it is full.
uniform float wear_from : hint_range(0.0, 1.0) = 0.55;
uniform float wear_to : hint_range(0.0, 1.0) = 0.86;
// Flagstones: their size in cells, how much the joints show, and how much each stone's tone strays.
uniform float stone_size = 0.27;
uniform float joints : hint_range(0.0, 1.0) = 0.6;
uniform float stone_tone : hint_range(0.0, 0.3) = 0.09;
uniform float fibre : hint_range(0.0, 0.5) = 0.08;

group_uniforms light;
// The same warm sun and cool fill as the painted paper (STYLE.md: sun #ffd9a8, sky #b9cbe0).
uniform vec3 light_warm : source_color = vec3(1.0, 0.851, 0.659);
uniform vec3 shade_cool : source_color = vec3(0.725, 0.796, 0.878);
uniform float warmth : hint_range(0.0, 1.0) = 0.3;
uniform float wrap : hint_range(0.0, 1.0) = 0.45;
group_uniforms;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	float across = abs(UV.y);
	vec4 n = texture(paper_noise, world_pos.xz * 0.9);
	vec4 broad = texture(paper_noise, world_pos.xz * 0.11 + vec2(0.31, 0.77));
	// a worn edge that wanders a little
	float wear = smoothstep(wear_from, wear_to, across + (broad.g - 0.5) * 0.15);
	vec3 colour = mix(road_light, road_edge, wear);
	// flagstones in rows, each row shifted, the grid bent by the noise so they are not a grid
	vec2 p = world_pos.xz / stone_size + (vec2(broad.r, broad.b) - 0.5) * 0.5;
	float row = floor(p.y);
	p.x += hash(vec2(row, 3.7)) * 0.9;
	vec2 cell = floor(p);
	vec2 inside = fract(p);
	float edge = min(min(inside.x, 1.0 - inside.x), min(inside.y, 1.0 - inside.y));
	float width = fwidth(p.x) + fwidth(p.y);
	// joints fade out before they are too fine to draw, and on the worn edge
	float fade = (1.0 - smoothstep(0.25, 0.6, width)) * (1.0 - wear);
	float joint = (1.0 - smoothstep(0.03, 0.03 + width * 1.5, edge)) * joints * fade;
	colour *= 1.0 + (hash(cell) - 0.5) * 2.0 * stone_tone * fade;
	colour = mix(colour, joint_colour, joint);
	// the lip's outer face, past its crest
	colour = mix(colour, lip_colour, smoothstep(0.95, 1.0, across));
	colour *= 1.0 + fibre * (n.b - 0.5);
	ALBEDO = colour;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}

void light() {
	float lit = smoothstep(0.0, 1.0, clamp((dot(NORMAL, LIGHT) + wrap) / (1.0 + wrap), 0.0, 1.0));
	vec3 tint = mix(vec3(1.0), light_warm, warmth);
	DIFFUSE_LIGHT += lit * ATTENUATION * LIGHT_COLOR * tint / PI;
	if (LIGHT_IS_DIRECTIONAL) {
		DIFFUSE_LIGHT += (1.0 - lit * ATTENUATION) * shade_cool * 0.18 * LIGHT_COLOR / PI;
	}
}
