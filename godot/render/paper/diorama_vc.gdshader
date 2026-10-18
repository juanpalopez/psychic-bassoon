// The diorama's generated props (#325, #326): faceted card with its colours in the vertex
// colours (times the MultiMesh instance colour, which Godot multiplies into COLOR), matte, with
// paper fibre, a wrapped warm light and a cool fill on the side away from the sun
// (docs/art/STYLE.md). One surface a prop, so one draw call a prop type. Nothing reads the
// screen, so Compatibility, Mobile and Forward+ draw it the same.
shader_type spatial;
render_mode cull_back;

uniform sampler2D paper_noise : hint_default_white, filter_linear_mipmap, repeat_enable;

group_uniforms light;
uniform vec3 light_warm : source_color = vec3(1.0, 0.851, 0.659);
uniform vec3 shade_cool : source_color = vec3(0.725, 0.796, 0.878);
uniform float warmth : hint_range(0.0, 1.0) = 0.3;
uniform float wrap : hint_range(0.0, 1.0) = 0.45;
uniform float fibre : hint_range(0.0, 0.5) = 0.12;
group_uniforms;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec4 n = texture(paper_noise, world_pos.xz * 1.7 + vec2(world_pos.y * 0.9));
	ALBEDO = COLOR.rgb * (1.0 + fibre * (n.b - 0.5) * 2.0);
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
