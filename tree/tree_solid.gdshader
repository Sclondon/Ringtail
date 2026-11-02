// TreeGen's solid parts: the trunk, branches and roots, the dark mass inside the crown, and the
// "blobs" leaf clumps. Vertex colours (sRGB); UV2.y how much each corner sways. With a bark texture
// (TreeGen.bark_style), the wood (UV2.x 1) has it over its colour: UV round it and along it, in tiles.
shader_type spatial;
render_mode cull_back, specular_disabled;

#include "res://tree/tree_common.gdshaderinc"

uniform bool use_bark = false;
// (greys about 0.5: doubled over the bark colour)
uniform sampler2D bark_tex : filter_linear_mipmap, repeat_enable;

varying float v_wood;

void vertex() {
	v_sway = UV2.y;
	v_wood = UV2.x;
	vec3 shift = tree_wind(MODEL_MATRIX, VERTEX, UV2.y, TIME);
	VERTEX += (inverse(MODEL_MATRIX) * vec4(shift, 0.0)).xyz;
	COLOR.rgb = tree_srgb(COLOR.rgb);
}

void fragment() {
	vec3 albedo = COLOR.rgb;
	if (use_bark && v_wood > 0.5) {
		albedo *= texture(bark_tex, UV).rgb * 2.0;
	}
	vec3 emission = vec3(0.0);
	tree_debug(albedo, emission, NORMAL, INV_VIEW_MATRIX, v_sway);
	ALBEDO = albedo;
	EMISSION = emission;
	ROUGHNESS = 1.0;
}
