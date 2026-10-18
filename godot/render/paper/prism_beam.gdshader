// The Prism Spire's beam: light split by the marble into a rainbow round a white core,
// with bright pulses running down it to the foe. Unshaded and added on top, so it glows on
// the desk. The pulses and the width (which throbs as a whole: the tube has rings only at its
// two ends) step at 12 fps like the rest of the stop-motion; the
// tube is `ShotsView`'s beam mesh (UV.x round it, UV.y along it, 0 at the tower).
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;

uniform float strength = 1.6;

varying float length_m;

void vertex() {
	float stepped = floor(TIME * 12.0) / 12.0;
	// the node is stretched along its length, so its z basis is the beam's length
	length_m = length(MODEL_MATRIX[2].xyz);
	float pulse = 1.0 + 0.22 * sin(stepped * 31.0);
	VERTEX.xy *= pulse;
}

vec3 hue(float h) {
	vec3 k = clamp(abs(fract(vec3(h) + vec3(0.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0) - 1.0, 0.0, 1.0);
	return k;
}

void fragment() {
	float stepped = floor(TIME * 12.0) / 12.0;
	// how far from the core this side of the tube is, seen from the camera
	float edge = 1.0 - abs(dot(NORMAL, VIEW));
	vec3 rainbow = hue(UV.x + UV.y * 0.25 - stepped * 0.4);
	vec3 core = vec3(1.0, 0.97, 0.9);
	vec3 colour = mix(core, rainbow, smoothstep(0.05, 0.45, edge));
	// pulses travelling to the foe, about two a metre
	float runs = fract(UV.y * length_m * 2.0 - stepped * 9.0);
	float bright = 0.55 + 0.75 * smoothstep(0.6, 1.0, runs);
	float fade = smoothstep(0.0, 0.08, UV.y) * (1.0 - 0.6 * edge);
	ALBEDO = colour * bright * fade * strength;
}
