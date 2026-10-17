// The Blot: wet purple ink that breathes a little and catches a violet sheen at grazing
// angles (the GDD's vertex displacement with a purple specular).
shader_type spatial;
render_mode cull_disabled;

uniform vec3 ink : source_color = vec3(0.19, 0.04, 0.31);
uniform vec3 sheen : source_color = vec3(0.55, 0.25, 0.85);
uniform float breathe = 0.004;

void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float lift = smoothstep(0.0, 0.01, VERTEX.y);
	VERTEX.y += sin(TIME * 1.3 + w.x * 2.1 + w.z * 1.7) * breathe * lift;
}

void fragment() {
	ALBEDO = ink;
	ROUGHNESS = 0.06;
	SPECULAR = 0.9;
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	EMISSION = sheen * rim * 0.35;
}
