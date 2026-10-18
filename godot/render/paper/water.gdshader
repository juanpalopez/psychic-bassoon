// The river in its gorge (#324): light to deep blue with a soft moving sheen, and white foam
// where it meets the banks (the vertex alpha, broken up by the paper noise). The one surface
// allowed to shine (STYLE.md). The Environment's depth haze (DioramaLens) fades it like the
// ground.
shader_type spatial;

uniform sampler2D paper_noise : hint_default_white, filter_linear_mipmap, repeat_enable;
// STYLE.md: water light #7fc4f2 and deep #2f6fbf.
uniform vec3 water_light : source_color = vec3(0.498, 0.769, 0.949);
uniform vec3 water_deep : source_color = vec3(0.184, 0.435, 0.749);
uniform vec3 foam_colour : source_color = vec3(0.933, 0.965, 0.984);
// Metres a second the ripples drift downstream (+z), and how glossy the open water is.
uniform float flow = 0.35;
uniform float gloss : hint_range(0.0, 1.0) = 0.75;

varying vec3 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 at = world_position.xz;
	float slow = texture(paper_noise, at * 0.18 + vec2(0.0, -TIME * flow * 0.18)).r;
	float fast = texture(paper_noise, at * 0.55 + vec2(0.37, -TIME * flow * 0.55)).g;
	vec3 water = mix(water_deep, water_light, clamp(0.25 + 0.6 * slow + 0.2 * (fast - 0.5), 0.0, 1.0));
	float foam = smoothstep(0.45, 0.85, COLOR.a + 0.35 * (fast - 0.5));
	ALBEDO = mix(water, foam_colour, foam);
	ROUGHNESS = mix(1.0 - gloss, 0.9, foam);
	SPECULAR = mix(0.5, 0.1, foam);
	METALLIC = 0.0;
}
