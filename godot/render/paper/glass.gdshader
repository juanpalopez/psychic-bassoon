// The Prism Spire's glass marble: a tinted, mostly see-through shell, brighter at its rim.
// The glowing cat's-eye inside is craft_vc paper. Alpha blending (it started on GL Compatibility).
shader_type spatial;
render_mode blend_mix, cull_back, depth_draw_opaque;

uniform vec4 tint : source_color = vec4(0.62, 0.86, 1.0, 1.0);
uniform float clarity = 0.22;

void fragment() {
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.5);
	ALBEDO = tint.rgb;
	ALPHA = clamp(clarity + 0.65 * rim, 0.0, 1.0);
	ROUGHNESS = 0.08;
	SPECULAR = 0.8;
	EMISSION = tint.rgb * rim * 0.25;
}
