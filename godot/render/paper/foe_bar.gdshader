// A health bar quad that always faces the camera. Each bar is two instances of one quad
// (a dark back and a coloured fill); the instance colour is the bar's colour.
// INSTANCE_CUSTOM.x shifts the quad sideways on the screen (so the fill stays on the
// bar's left edge) and .y moves it towards the camera (so the fill is not hidden by the back).
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque;

void vertex() {
	vec3 size = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), 1.0);
	mat4 facing = mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = VIEW_MATRIX * facing;
	MODELVIEW_MATRIX[0] *= size.x;
	MODELVIEW_MATRIX[1] *= size.y;
	MODELVIEW_MATRIX[3].x += INSTANCE_CUSTOM.x;
	MODELVIEW_MATRIX[3].z += INSTANCE_CUSTOM.y;
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
	ALBEDO = COLOR.rgb;
}
