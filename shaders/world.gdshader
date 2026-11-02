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
// How much a large, slow variation in world space breaks up the texture's repeat (patches of newer and older
// tarmac on the roads; the user, 2026-11-02, "less repetitive texture"): 0 off.
uniform float variation = 0.0;
// Rows of the grid the corners snap to (0: off).
uniform float snap = 0.0;  // (off: the user, 2026-11-01, "the world vibrates slightly when you move things jiggle")

varying vec3 model_pos;
varying vec3 model_normal;
varying vec3 world_pos;

float hash2(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash2(i), hash2(i + vec2(1.0, 0.0)), u.x), mix(hash2(i + vec2(0.0, 1.0)), hash2(i + vec2(1.0, 1.0)), u.x), u.y);
}

void vertex() {
	model_pos = VERTEX;
	model_normal = NORMAL;
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
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
		if (variation > 0.0) {
			// (the texture again at another scale and turned, blended in by a slow noise: no two stretches alike)
			vec2 turned = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8)) * uv * 0.37 + vec2(0.31, 0.17);
			float blend = value_noise(world_pos.xz * 0.045);
			painted = mix(painted, texture(tex, turned / tile).rgb, blend * variation);
			float patches = value_noise(world_pos.xz * 0.09) * 0.65 + value_noise(world_pos.xz * 0.4) * 0.35;
			painted *= mix(1.0, 0.8 + 0.4 * patches, variation);
		}
	}
	ALBEDO = albedo * painted * COLOR.rgb;
	EMISSION = albedo * emission;
	ROUGHNESS = 1.0;
}
