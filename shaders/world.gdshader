shader_type spatial;
// The world in an N64 way: a flat colour shaded by the vertex colours baked in Blender,
// its corners snapped to a coarse screen grid so they jitter a little
// as the camera moves (the console had no sub-pixel precision).
render_mode cull_disabled, specular_disabled;

uniform vec3 albedo : source_color = vec3(1.0);
uniform float emission = 0.0;
// Rows of the grid the corners snap to (0: off).
uniform float snap = 240.0;

void vertex() {
	if (snap > 0.0) {
		vec4 clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
		vec2 grid = vec2(snap * VIEWPORT_SIZE.x / VIEWPORT_SIZE.y, snap) * 0.5;
		clip.xy = round(clip.xy / clip.w * grid) / grid * clip.w;
		POSITION = clip;
	}
}

void fragment() {
	ALBEDO = albedo * COLOR.rgb;
	EMISSION = albedo * emission;
	ROUGHNESS = 1.0;
}
