// Plain coloured paper for props (trees, shrubs, buttons, the Heartstone): a fibre texture,
// matte, and a wrapped light so thin paper softens round the terminator. `glow` lights it
// from inside.
shader_type spatial;
render_mode cull_disabled;

uniform sampler2D paper_noise : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform vec3 colour : source_color = vec3(0.8, 0.78, 0.72);
uniform float glow = 0.0;
uniform float wrap = 0.35;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
	vec4 n = texture(paper_noise, world_pos.xz * 1.3 + vec2(world_pos.y * 0.7));
	ALBEDO = colour * (0.9 + 0.2 * n.r);
	ROUGHNESS = 0.85;
	EMISSION = colour * glow;
}

void light() {
	float wrapped = clamp((dot(NORMAL, LIGHT) + wrap) / (1.0 + wrap), 0.0, 1.0);
	DIFFUSE_LIGHT += wrapped * ATTENUATION * LIGHT_COLOR / PI;
}
