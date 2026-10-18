// The towers and units: paper and the found objects of the craft room (a spool, a thimble,
// toothpicks, foil, a bottle cap) on one surface a part, so a part is one draw call. The
// colours are in the vertex colours and the look of each face in UV2.x, written by
// assets-src/papercraft/towers_export.py: 0 paper, 1 wood, 2 metal, 3 dimpled metal (the
// thimble), 4 wound thread, 5 corrugated card. Vertex alpha lights paper from inside. All of it
// is the matte painted paper of painted.gdshaderinc: metal reads as foil card by its colour and
// pattern, not by a shine (STYLE.md: nothing is glossy or metallic).
shader_type spatial;
render_mode cull_disabled;

#include "res://render/paper/painted.gdshaderinc"

uniform float glow = 0.9;

varying vec3 local_pos;
varying float kind;

void vertex() {
	PAINTED_VERTEX
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
	// every pattern's input and its derivative, before the branches
	float n = texture(paper_noise, painted_world.xz * 1.3 + vec2(painted_world.y * 0.7)).g;
	float grain = length(local_pos.xz) * 26.0 + local_pos.y * 3.0 + n * 1.5;
	float winds = local_pos.y * 40.0;
	float flutes = UV.x * 30.0;
	float grain_w = fwidth(grain);
	float winds_w = fwidth(winds);
	float flutes_w = fwidth(flutes);
	vec3 albedo = COLOR.rgb;
	if (k == 1) {
		// wood grain: soft rings round the piece's own axis, wobbled by the noise
		albedo *= 0.9 + 0.14 * stripes(grain, grain_w);
	} else if (k == 2 || k == 3) {
		// foil card: a little lighter, with a soft crinkle instead of a highlight
		albedo *= 1.04 + 0.12 * (n - 0.5);
		if (k == 3) {
			// the thimble's dimples: a grid of dots on its turned surface
			vec2 cell = fract(vec2(UV.x * 8.0, UV.y * 30.0)) - 0.5;
			float dimple = 1.0 - smoothstep(0.2, 0.34, length(cell));
			albedo *= 1.0 - 0.38 * dimple;
		}
	} else if (k == 4) {
		// thread wound round the spool: fine bands up its height
		albedo *= 0.55 + 0.5 * stripes(winds, winds_w);
	} else if (k == 5) {
		// corrugated card seen on its cut edge: the flutes along the edge
		albedo *= 0.62 + 0.45 * stripes(flutes, flutes_w);
	}
	PAINTED_PAPER(albedo, 1.0)
	EMISSION = k == 0 ? COLOR.rgb * COLOR.a * glow : vec3(0.0);
}
