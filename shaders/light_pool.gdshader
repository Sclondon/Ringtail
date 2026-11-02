// A pool of lamplight on the ground (DayNight's street lights): a disc added over what is under it, brightest in the
// middle and faded to nothing at its rim. No real light: the few lamps nearest him have those.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform vec3 colour : source_color = vec3(1.0, 0.62, 0.28);
uniform float strength = 0.0;

void fragment() {
	float r = length(UV - 0.5) * 2.0;
	float a = 1.0 - smoothstep(0.0, 1.0, r);
	ALBEDO = colour * a * a * strength;
}
