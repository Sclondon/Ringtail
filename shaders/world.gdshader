shader_type spatial;
// The world in an N64 way: a Banjo-style painted texture (tools/make_textures.gd), tiled by metres, tinted and shaded
// by the vertex colours baked in Blender, filtered smooth; its corners snapped to a coarse screen grid so they jitter
// a little as the camera moves (the console had no sub-pixel precision).
render_mode cull_disabled, specular_disabled;

uniform vec3 albedo : source_color = vec3(1.0);
uniform sampler2D tex : source_color, filter_linear_mipmap, repeat_enable;
uniform bool textured = false;
// Metres to one repeat of the texture.
uniform float tile = 1.5;
// Laid on by where each point is in the model, from the side it faces (for models without texture coordinates;
// in the model's space, so it stays put on something that tumbles).
uniform bool box_mapped = false;
uniform float emission = 0.0;
// Rows of the grid the corners snap to (0: off).
uniform float snap = 0.0;  // (off: the user, 2026-11-01, "the world vibrates slightly when you move things jiggle")

varying vec3 model_pos;
varying vec3 model_normal;

void vertex() {
	model_pos = VERTEX;
	model_normal = NORMAL;
	// (POSITION, once a shader writes it anywhere, is always used: so it is always written)
	vec4 clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	if (snap > 0.0) {
		vec2 grid = vec2(snap * VIEWPORT_SIZE.x / VIEWPORT_SIZE.y, snap) * 0.5;
		clip.xy = round(clip.xy / clip.w * grid) / grid * clip.w;
	}
	POSITION = clip;
}

void fragment() {
	vec3 painted = vec3(1.0);
	if (textured) {
		vec2 uv = UV;
		if (box_mapped) {
			vec3 n = abs(model_normal);
			uv = n.y > 0.7 ? model_pos.xz : (n.x > n.z ? vec2(model_pos.z, -model_pos.y) : vec2(model_pos.x, -model_pos.y));
		}
		painted = texture(tex, uv / tile).rgb;
	}
	ALBEDO = albedo * painted * COLOR.rgb;
	EMISSION = albedo * emission;
	ROUGHNESS = 1.0;
}
