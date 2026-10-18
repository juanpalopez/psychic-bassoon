// The haze the diorama fades into past the map (#324): an exact colour mixed over the lit
// surface through FOG, by how far the point lies outside the map (metres from its edge, the
// near and right sides, toward the camera, a little clearer). Its colour is the
// Environment's background, so the world's last cells meet the background with no edge.
// Include it, then write `HAZE_FOG(world_position)` in fragment().

group_uniforms haze;
// STYLE.md: warm haze #c7bdb3.
uniform vec3 haze_colour : source_color = vec3(0.78, 0.741, 0.702);
// Half the map's size in metres (x across, y in depth); `Diorama` sets it.
uniform vec2 map_half = vec2(16.0, 10.0);
// The haze starts this far past the map's edge and is whole this far out.
uniform float haze_from = 4.0;
uniform float haze_to = 30.0;
// How much clearer the side toward the camera stays.
uniform float haze_front_clear : hint_range(0.0, 1.0) = 0.35;
uniform float haze_curve : hint_range(0.3, 3.0) = 1.3;
group_uniforms;

float haze_amount(vec3 world) {
	vec2 out_by = max(abs(world.xz) - map_half, vec2(0.0));
	float past = length(out_by);
	vec2 side = sign(world.xz) * out_by;
	float front = past > 0.0 ? clamp(dot(side / past, vec2(0.5, 0.866)), 0.0, 1.0) : 0.0;
	float amount = clamp((past - haze_from) / (haze_to - haze_from), 0.0, 1.0);
	amount = pow(amount, haze_curve) * (1.0 - haze_front_clear * front);
	return amount;
}

#define HAZE_FOG(world) FOG = vec4(haze_colour, haze_amount(world));
