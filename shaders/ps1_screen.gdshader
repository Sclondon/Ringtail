shader_type canvas_item;
// The picture as Close Encounters draws it (its shaders/screen.gdshader, after Cryptlins' ps1_screen): the world at
// `lines` lines high, blown up with hard pixels, cut down to 15-bit colour with the PlayStation's own 4x4 dither
// pattern, and darkened at the corners. Here it is read off the screen under the HUD rather than from a small
// viewport (the user, 2026-11-02: "the pixel filter should be more like close encounters").

uniform sampler2D screen : hint_screen_texture, filter_nearest;
uniform float lines = 300.0;
uniform bool dither = true;

const float DITHER[16] = float[](-4.0, 0.0, -3.0, 1.0, 2.0, -2.0, 3.0, -1.0, -3.0, 1.0, -4.0, 0.0, 3.0, -1.0, 2.0, -2.0);

void fragment() {
	vec2 size = 1.0 / SCREEN_PIXEL_SIZE;
	vec2 res = floor(vec2(lines * size.x / size.y, lines));
	vec2 px = floor(SCREEN_UV * res);
	vec3 c = texture(screen, (px + 0.5) / res).rgb;
	vec2 off = SCREEN_UV - 0.5;
	c *= 1.0 - dot(off, off) * 0.9;
	if (dither) {
		c *= 255.0;
		c += DITHER[int(mod(px.x, 4.0)) + int(mod(px.y, 4.0)) * 4];
		c = floor(clamp(c, 0.0, 255.0) / 8.0) * 8.0 / 248.0;
	}
	COLOR = vec4(c, 1.0);
}
