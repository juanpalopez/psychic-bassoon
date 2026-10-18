// Hand-Folded Fantasy (docs/art/STYLE.md): the painted paper every lit surface shares.
//
// A shader includes this file, writes PAINTED_VERTEX in vertex() and PAINTED_PAPER(colour,
// contact, fold) in fragment(), and the light() below does the rest:
// - warm where the sun hits and cool where it does not, with a wide soft ramp between them
//   (wrap lighting and a smooth falloff across the face, never a band or a cel step);
// - matte paper and card: no specular from the lights and no reflections (only water and
//   magic shine, and they have their own shaders);
// - fibre and a broad painted wash in the albedo, so no fill is flat. They lie in the world,
//   or on the model when the shader defines PAINTED_OBJECT_SPACE before the include (anything
//   that moves, such as the foes, so the fibre does not crawl over a walking body);
// - darker folds where the caller says (a fold value its builder bakes into the vertex
//   colour, UV2 or a map: #324 to #326), and a darker cut edge where a sheet turns away;
// - contact shading: the caller's baked value (vertex alpha or a map), times a darkening at
//   the foot of anything standing on the ground (strong ambient occlusion where things meet
//   it, which the phone has no SSAO for); a look for something that hovers sets
//   ground_contact to 0.
// Nothing here reads the screen, so Forward+ and Mobile draw it the same. Cost: three
// texture reads from one small noise map (grain, strands, wash) and a handful of mixes a
// pixel, and a few more mixes a light; no extra pass and no extra draw call.

uniform sampler2D paper_noise : hint_default_white, filter_linear_mipmap, repeat_enable;

group_uniforms painted_light;
// The sun's warmth (STYLE.md: sun #ffd9a8), added on the sun-lit side on top of the sun's own
// colour; other lights keep their colour.
uniform vec3 light_warm : source_color = vec3(1.0, 0.851, 0.659);
// The cool of the sky (STYLE.md: sky #b9cbe0) that fills the side the sun does not reach.
uniform vec3 shade_cool : source_color = vec3(0.725, 0.796, 0.878);
uniform float warmth : hint_range(0.0, 1.0) = 0.25;
// How far round the terminator the light wraps: thin card softens there instead of cutting off.
uniform float wrap : hint_range(0.0, 1.0) = 0.5;
// How much cool light the shadow side gets from the sun's bounce, as a share of the sun.
uniform float shade_fill : hint_range(0.0, 1.0) = 0.2;

group_uniforms painted_paper;
// The fine fibre and strands in the paper, and the broad painted wash across a surface.
uniform float fibre : hint_range(0.0, 0.5) = 0.12;
uniform float wash : hint_range(0.0, 0.5) = 0.1;
// Baked folds and the cut edge of a sheet seen side on darken towards this colour
// (STYLE.md: soil lip, deep shade #3e2b1c).
uniform vec3 fold_colour : source_color = vec3(0.243, 0.169, 0.11);
uniform float fold_darken : hint_range(0.0, 1.0) = 0.5;
uniform float edge_darken : hint_range(0.0, 1.0) = 0.08;

group_uniforms painted_contact;
// How much of the baked contact value shows (0 ignores it).
uniform float contact : hint_range(0.0, 1.0) = 0.85;
// How much the contact also darkens the sun's light, not only the sky's (AO alone is ambient).
uniform float contact_direct : hint_range(0.0, 1.0) = 0.6;
// The darkening at the foot of upright faces, within this many metres of the model's origin
// (a narrow band: about a sixth of the Scrap Goblin, the smallest foe).
uniform float ground_contact : hint_range(0.0, 1.0) = 0.45;
uniform float ground_contact_height : hint_range(0.01, 2.0) = 0.12;
group_uniforms;

varying vec3 painted_world;
varying vec3 painted_up;
varying float painted_height;
varying float painted_contact;
// where the fibre and the wash are read: the world, or the model in metres
varying vec3 painted_paper_pos;
varying vec3 painted_paper_up;

// In vertex(): where the vertex is in the world, its world normal, and how high it stands
// above its model's origin in metres (the origin is the model's foot on the ground).
#ifdef PAINTED_OBJECT_SPACE
#define PAINTED_PAPER_SPACE \
	painted_paper_pos = VERTEX * length(MODEL_MATRIX[0].xyz); \
	painted_paper_up = NORMAL;
#else
#define PAINTED_PAPER_SPACE \
	painted_paper_pos = painted_world; \
	painted_paper_up = painted_up;
#endif
#define PAINTED_VERTEX \
	painted_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; \
	painted_up = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz); \
	painted_height = painted_world.y - MODEL_MATRIX[3].y; \
	PAINTED_PAPER_SPACE

// In fragment(): paper of colour `base` (linear) with baked contact `baked` (1 open, 0 shut
// in) and a baked fold `folded` (0 flat, 1 on the crease). It writes ALBEDO, AO, ROUGHNESS
// and SPECULAR; write EMISSION or NORMAL_MAP after it.
#define PAINTED_PAPER(base, baked, folded) \
	{ \
		float painted_rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0); \
		vec3 painted_albedo = painted_tone(base, painted_paper_pos, painted_paper_up); \
		float painted_dark = clamp((folded) * fold_darken + painted_rim * edge_darken, 0.0, 1.0); \
		ALBEDO = mix(painted_albedo, fold_colour * painted_albedo * 2.0, painted_dark); \
		painted_contact = painted_contact_of(baked, painted_height, painted_up); \
		AO = painted_contact; \
		ROUGHNESS = 1.0; \
		SPECULAR = 0.0; \
	}

// The noise map's coordinates on the plane a face mostly lies in, so fibre runs the same on
// a wall as on a floor.
vec2 painted_plane(vec3 world, vec3 up) {
	vec3 painted_a = abs(up);
	if (painted_a.y >= painted_a.x && painted_a.y >= painted_a.z) {
		return world.xz;
	}
	return painted_a.x > painted_a.z ? world.zy : world.xy;
}

// The noise map: r runs in streaks, g is broad blotches, b is fine speckle (paper_noise.png).
vec3 painted_tone(vec3 base, vec3 world, vec3 up) {
	// local names carry the prefix: a shader's own uniform of the same name would win
	vec2 painted_p = painted_plane(world, up);
	float painted_grain = texture(paper_noise, painted_p * 2.3).b - 0.3;
	// short strands turned off the map's own streaks, so the fibre does not read as brushed metal
	vec2 painted_turned = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8)) * painted_p;
	float painted_strands = smoothstep(0.78, 0.98, texture(paper_noise, painted_turned * 1.9).r);
	// one broad read for the wash: g for light and dark, a for warm and cool
	vec4 painted_wash = texture(paper_noise, painted_p * 0.06 + vec2(0.37, 0.71));
	float painted_broad = (painted_wash.g - 0.47) * 2.0;
	float painted_hue = (painted_wash.a - 0.47) * 2.0;
	vec3 painted_col = base * (1.0 + fibre * (painted_grain * 1.6 + painted_strands * 0.5));
	// the wash: a little lighter and warmer here, a little darker and cooler there
	painted_col *= 1.0 + wash * painted_broad;
	painted_col *= 1.0 + wash * painted_hue * vec3(0.5, 0.1, -0.5);
	return painted_col;
}

float painted_contact_of(float baked, float height, vec3 up) {
	float painted_upright = 1.0 - smoothstep(0.55, 0.9, up.y);
	float painted_foot = 1.0 - smoothstep(0.0, ground_contact_height, height);
	return mix(1.0, baked, contact) * (1.0 - ground_contact * painted_upright * painted_foot);
}

void light() {
	float painted_wrapped = clamp((dot(NORMAL, LIGHT) + wrap) / (1.0 + wrap), 0.0, 1.0);
	// a smooth ramp, so the light falls off across a face and rolls round its edge
	float painted_lit = smoothstep(0.0, 1.0, painted_wrapped) * ATTENUATION;
	vec3 painted_light = painted_lit * LIGHT_COLOR;
	if (LIGHT_IS_DIRECTIONAL) {
		painted_light *= mix(vec3(1.0), light_warm, warmth);
		// the side away from the sun (and the ground in its shadow) is filled cool, not black
		float painted_strength = dot(LIGHT_COLOR, vec3(0.2126, 0.7152, 0.0722));
		painted_light += shade_cool * shade_fill * (1.0 - painted_lit) * painted_strength;
	}
	DIFFUSE_LIGHT += painted_light * mix(1.0, painted_contact, contact_direct) / PI;
}
