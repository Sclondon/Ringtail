shader_type spatial;
// One puff of cloud as Daughter Of The Wind draws them (its shaders/cloud_puff, brought into the weather:
// WeatherRig.cloud_look PUFFS): a solid lumpy ball, not a see-through card, so nothing is blended or
// sorted and nothing is done for each puff on the CPU once the clouds are laid out.
//  - the sphere is swollen into round billows by noise, with smaller domes (cell noise) on top;
//  - it is lit in flat cel tones with a normal leaning hard toward "away from the middle of its
//    cloud", so a heap shades as one mass, not a pile of balls;
//  - its rim is feathered, a dithered band at the silhouette of slow-changing width;
//  - some puffs carry a painted curl (Okami, The Wind Waker).
// The heaps drift on the wind and wrap round the camera here, in the vertex shader (`drift`, `field`).
//
// Per puff, its MultiMesh transform is not a transform but a packet (the mesh is a unit sphere):
//   column 0 = (radius, offset x, offset y)   column 1 = (offset z, flat base height, wraps 0/1)
//   column 3 = its cloud's middle, as laid out (before the drift)
//   INSTANCE_CUSTOM = (height in its cloud 0..1, how dark its belly gets, seed, squash 1 round .. flat)
render_mode unshaded, cull_back, fog_disabled, shadows_disabled;

uniform sampler2D noise_tex : repeat_enable, filter_linear_mipmap;
uniform vec3 light_dir = vec3(0.0, 0.8, -0.6);
uniform vec3 light_color : source_color = vec3(1.0);
uniform float light_energy = 1.2;
uniform vec3 ambient : source_color = vec3(0.5, 0.55, 0.65);
uniform vec3 horizon : source_color = vec3(0.7, 0.8, 0.9);
uniform float warmth = 0.0;
uniform float opacity = 1.0;
uniform float fade_far = 9000.0;
uniform vec3 flash_pos = vec3(0.0);
uniform float flash = 0.0;
uniform float gloom = 0.0;
uniform float belly = 1.0;
uniform float lining = 1.0;
uniform vec3 tint : source_color = vec3(1.0);
uniform float flash_light = 1.0;
// The wind's drift so far (m), and the half width of the square the heaps wrap round the camera in.
uniform vec2 drift = vec2(0.0);
uniform float field = 7000.0;
// How much of the painted curls to draw (0 none).
uniform float curls = 1.0;

varying vec3 world;
varying vec3 w_normal;
varying vec3 l_dir;
varying vec4 info;
varying vec3 core_dir;
varying float crease;
varying float feather;
varying float puff_r;

// Cell-noise domes (green) wrapped round the sphere from three sides.
float domes(vec3 dir, float seed) {
	vec3 w = dir * dir;
	float x = textureLod(noise_tex, dir.zy * 0.2 + seed, 0.0).g;
	float y = textureLod(noise_tex, dir.xz * 0.2 + seed * 1.7, 0.0).g;
	float z = textureLod(noise_tex, dir.xy * 0.2 + seed * 2.9, 0.0).g;
	float d = x * w.x + y * w.y + z * w.z;
	return 1.0 - d * d;
}

void vertex() {
	info = INSTANCE_CUSTOM;
	float radius = MODEL_MATRIX[0].x;
	vec3 off = vec3(MODEL_MATRIX[0].y, MODEL_MATRIX[0].z, MODEL_MATRIX[1].x);
	float flat_y = MODEL_MATRIX[1].y;
	vec3 middle = MODEL_MATRIX[3].xyz;
	vec3 cam = INV_VIEW_MATRIX[3].xyz;
	if (MODEL_MATRIX[1].z > 0.5) {
		middle.xz = mod(middle.xz + drift - cam.xz + field, field * 2.0) - field + cam.xz;
	}
	// Which way this puff lies from the middle of its heap: out, and up or down by its height in it.
	vec2 out_dir = length(off.xz) > 0.001 ? normalize(off.xz) : vec2(0.0);
	core_dir = normalize(vec3(out_dir.x, info.x * 2.2 - 0.9, out_dir.y));
	vec3 dir = normalize(VERTEX);
	float seed = info.z * 13.7;
	float big = textureLod(noise_tex, dir.xz * 0.33 + vec2(seed, seed * 1.7) + TIME * 0.003, 0.0).r;
	float small = textureLod(noise_tex, dir.xy * 0.85 + vec2(seed * 3.1, seed * 0.7), 0.0).r;
	float dome = domes(dir, seed);
	crease = dome;
	vec3 v = dir * (1.0 + (big - 0.5) * 0.3 + (small - 0.5) * 0.06 + (dome - 0.55) * 0.3);
	v.y *= info.w;
	world = middle + off + v * radius;
	// Its normal, as squashed (an ellipsoid's).
	vec3 normal = normalize(vec3(dir.x, dir.y / max(info.w, 0.2), dir.z));
	// Cumulus sit on a flat base: what hangs below it is squashed up to it, and faces down.
	if (world.y < flat_y) {
		world.y = mix(world.y, flat_y, 0.82);
		normal = normalize(mix(normal, vec3(0.0, -1.0, 0.0), 0.82));
	}
	feather = textureLod(noise_tex, dir.zx * 0.21 + dir.y * 0.13 + vec2(seed * 2.3, seed) + TIME * 0.004, 0.0).r;
	l_dir = dir;
	w_normal = normal;
	puff_r = radius;
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(world, 1.0);
}

float dither(vec2 p) {
	return fract(52.9829189 * fract(dot(p, vec2(0.06711056, 0.00583715))));
}

// One arm of a spiral round the point `axis` on the puff, as a brush stroke (0..1).
float curl(vec3 d, vec3 axis, float seed, float size) {
	vec3 side = normalize(cross(axis, vec3(0.31, 0.9, 0.3)));
	vec3 up = cross(side, axis);
	vec2 q = vec2(dot(d, side), dot(d, up)) / size;
	float r = length(q);
	float a = atan(q.y, q.x);
	float arm = sin(a + log(r + 0.05) * 4.4 + seed * 6.283);
	float body = smoothstep(0.1, 0.3, r) * (1.0 - smoothstep(0.62, 0.95, r));
	float stroke = smoothstep(0.93 - 0.1 * body, 0.97 - 0.06 * body, arm) * body;
	return stroke * smoothstep(0.15, 0.4, dot(d, axis));
}

void fragment() {
	vec3 to_eye = CAMERA_POSITION_WORLD - world;
	float dist = length(to_eye);
	vec3 v = to_eye / dist;
	vec3 n = normalize(w_normal);
	float facing = dot(n, v);

	// Gone into the distance, past the square they wrap in (where they would pop), and too close.
	float fade = (1.0 - smoothstep(fade_far * 0.8, fade_far, dist))
		* (1.0 - smoothstep(field * 0.75, field * 0.95, length(world.xz - CAMERA_POSITION_WORLD.xz)))
		* smoothstep(puff_r * 0.2, puff_r * 1.2, dist) * opacity;
	// The feathered rim.
	float band = mix(0.05, 0.3, smoothstep(0.35, 0.7, feather));
	fade *= smoothstep(0.0, band, facing);
	if (fade < 0.999 && fade < dither(FRAGCOORD.xy)) {
		discard;
	}

	vec3 L = normalize(light_dir);
	float day = smoothstep(-0.1, 0.1, L.y);
	vec3 sun_col = mix(light_color, light_color * vec3(1.15, 0.72, 0.5), warmth) * light_energy;
	vec3 lit_color = ambient * 0.45 + sun_col * 0.85;
	// (the shade a pale blue-grey by day, as Daughter Of The Wind's, not a dark one)
	vec3 shade_color = mix(mix(ambient, horizon, 0.55) * 1.2, lit_color * vec3(0.66, 0.74, 0.9), 0.5 * day);
	// Mostly the cloud's own roundness, a little the puff's: the heap reads as one mass.
	vec3 soft = normalize(mix(n, core_dir, 0.68));
	float light = dot(soft, L) * 0.5 + 0.5;
	light *= mix(0.62, 1.0, smoothstep(-0.7, 0.4, mix(n.y, core_dir.y, 0.35)));
	light *= mix(0.78, 1.0, info.x);
	light *= mix(0.8, 1.0, smoothstep(0.25, 0.7, crease));
	// Cel shading: lit, a half tone, or shade.
	float tone = smoothstep(0.3, 0.36, light) * 0.6 + smoothstep(0.54, 0.6, light) * 0.4;
	vec3 col = mix(shade_color, lit_color, tone);
	col = mix(col, shade_color * 0.84, (1.0 - tone) * smoothstep(0.1, -0.8, n.y) * 0.7);
	// Storm bellies, darker the lower in the cloud.
	col *= mix(1.0, 0.35, clamp(info.y * belly, 0.0, 1.4) * (1.0 - info.x));

	// Painted curls: on about two puffs in three, gone with distance.
	float seed = info.z * 13.7;
	float paint = curls * step(fract(seed * 7.31), 0.66) * (1.0 - smoothstep(2500.0, 6000.0, dist));
	if (paint > 0.0) {
		vec3 d = normalize(l_dir);
		float t = seed * 39.0;
		vec3 a1 = normalize(vec3(cos(t), 0.45, sin(t)));
		vec3 a2 = normalize(vec3(cos(t + 2.6), 0.1, sin(t + 2.6)));
		float stroke = max(curl(d, a1, seed, 0.78), curl(d, a2, seed + 0.37, 0.55)) * paint;
		vec3 ink = mix(mix(shade_color, lit_color, 0.4), mix(shade_color, lit_color, 0.22), tone);
		col = mix(col, ink, stroke * 0.85);
	}

	col = mix(col, vec3(dot(col, vec3(0.33))) * vec3(0.9, 0.95, 1.05), gloom * 0.6) * mix(1.0, 0.6, gloom);
	// A silver lining when the sun is behind the cloud.
	float against = pow(max(dot(-v, L), 0.0), 5.0);
	col += sun_col * against * pow(1.0 - max(facing, 0.0), 2.0) * 0.7 * lining * day;
	// Lightning inside the cloud.
	float fd = length(world - flash_pos);
	col += vec3(0.85, 0.85, 1.0) * flash * flash_light * exp(-fd / 1400.0) * 1.6;
	// Into the haze with distance.
	col = mix(col, horizon, smoothstep(fade_far * 0.15, fade_far, dist) * 0.75);
	ALBEDO = col * tint;
}
