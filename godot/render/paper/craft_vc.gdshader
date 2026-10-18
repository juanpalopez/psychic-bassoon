// The towers and units: paper and the found objects of the craft room (a spool, a thimble,
// toothpicks, foil, a bottle cap) on one surface a part, so a part is one draw call. The
// colours are in the vertex colours and the look of each face in UV2.x, written by
// assets-src/papercraft/towers_export.py: 0 paper, 1 wood, 2 metal, 3 dimpled metal (the
// thimble), 4 wound thread, 5 corrugated card. Vertex alpha lights paper from inside.
// Plain branches (it started on GL Compatibility): a wrapped light like paper_vc, and a hand-made highlight
// on metal (the desk has no sky to reflect).
shader_type spatial;
render_mode cull_disabled;

uniform sampler2D paper_noise : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform float glow = 0.9;
uniform float wrap = 0.35;

varying vec3 world_pos;
varying vec3 local_pos;
varying float kind;
varying float shine;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	local_pos = VERTEX;
	kind = UV2.x;
}

// Fine stripes of `x` that fade out before they are too small to draw (no shimmer far away);
// `width` is fwidth(x), taken before any branch so the derivative is defined.
float stripes(float x, float width) {
	float fade = 1.0 - smoothstep(0.35, 0.9, width);
	return mix(0.5, 0.5 + 0.5 * sin(x * 6.2831853), fade);
}

void fragment() {
	int k = int(kind + 0.5);
	vec4 n = texture(paper_noise, world_pos.xz * 1.3 + vec2(world_pos.y * 0.7));
	// every pattern's input and its derivative, before the branches
	float grain = length(local_pos.xz) * 26.0 + local_pos.y * 3.0 + n.g * 1.5;
	float winds = local_pos.y * 40.0 + n.r * 0.4;
	float flutes = UV.x * 30.0;
	float grain_w = fwidth(grain);
	float winds_w = fwidth(winds);
	float flutes_w = fwidth(flutes);
	vec3 albedo = COLOR.rgb;
	float rough = 0.85;
	shine = 0.0;
	if (k == 0) {
		albedo *= 0.9 + 0.2 * n.r;
	} else if (k == 1) {
		// wood grain: soft rings round the piece's own axis, wobbled by the noise
		albedo *= 0.9 + 0.14 * stripes(grain, grain_w);
		rough = 0.72;
	} else if (k == 2 || k == 3) {
		shine = 1.0;
		rough = 0.35;
		if (k == 3) {
			// the thimble's dimples: a grid of dots on its turned surface
			vec2 cell = fract(vec2(UV.x * 8.0, UV.y * 30.0)) - 0.5;
			float dimple = 1.0 - smoothstep(0.2, 0.34, length(cell));
			albedo *= 1.0 - 0.38 * dimple;
			shine = 1.0 - 0.6 * dimple;
		}
	} else if (k == 4) {
		// thread wound round the spool: fine bands up its height
		albedo *= 0.55 + 0.5 * stripes(winds, winds_w);
		rough = 0.7;
	} else {
		// corrugated card seen on its cut edge: the flutes along the edge
		albedo *= 0.62 + 0.45 * stripes(flutes, flutes_w);
	}
	ALBEDO = albedo;
	ROUGHNESS = rough;
	EMISSION = k == 0 ? COLOR.rgb * COLOR.a * glow : vec3(0.0);
}

void light() {
	float wrapped = clamp((dot(NORMAL, LIGHT) + wrap) / (1.0 + wrap), 0.0, 1.0);
	DIFFUSE_LIGHT += wrapped * ATTENUATION * LIGHT_COLOR / PI * (1.0 - 0.15 * shine);
	vec3 half_vector = normalize(LIGHT + VIEW);
	float highlight = pow(max(dot(NORMAL, half_vector), 0.0), 36.0);
	SPECULAR_LIGHT += shine * highlight * ATTENUATION * LIGHT_COLOR * ALBEDO * 1.6;
}
