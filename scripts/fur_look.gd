class_name FurLook
extends RefCounted
## The fur's looks: its type (a model of its own for each: tools/build_raccoon.py and tools/build_cat.py, `fur=`),
## what is drawn on it (MARKS), a cat's markings (PATTERNS) and colours. The model editor (FurEditor) changes them;
## RaccoonRig (and so CatRig) wears them: `swap(rig)` puts the fur type's mesh on before it is shaded, `paint(rig)`
## sets what is drawn after (the user, 2026-11-02: "a model editor where I can switch out the fur with different
## texture types like the hair editor in gloaming").
##
## A look is a Dictionary: {"fur": type, "marks": mark, "pattern": pattern, "colours": {material name: Color}}. The
## hero's and each cat's are kept in FILE.

const FILE := "user://looks.json"
## His fur types (models/raccoon.glb is "spiky"; the others models/raccoon_fur_<type>.glb).
const TYPES := ["spiky", "soft", "shaggy", "sleek", "wiry", "cones"]
## The cats' (models/cat.glb is "spiky"; the others models/cat_<type>.glb).
const CAT_TYPES := ["spiky", "sleek", "shaggy", "soft"]
## What is drawn on the fur.
const MARKS := ["plain", "frosted", "dark_tips", "streaked", "stippled"]
## What each spike is made of: Gloaming's hair textures (its LockHair.TEXTURES; the user, 2026-11-02: "why aren't
## there the different textures from Gloaming?"): solid as drawn, or fine strands, straight, wavy, curly, soft, thick.
const TEXTURES := ["solid", "straight", "wavy", "curly", "soft", "thick"]
## The fur's shape, live (the user: "I should be able to control the angle of the fur and how dense, and the ring mane
## as well", "and the fur length"): [length, angle, density] for the body's, [length, angle, density (count), width]
## for the mane; and the tail's [length, thickness] ("I should be able to control tail length and thickness as well").
const BODY_SHAPE := [1.0, 0.0, 1.0]
const MANE_SHAPE := [1.0, 0.0, 1.0, 1.0]
const TAIL_SHAPE := [1.0, 1.0]
## Each part's own [size, width, density] (the user: "I should be able to control the width and size of each fur blade,
## and the density on different body parts"), by the regions it covers; "crown" is the short fur on his head (the
## mane is MANE_SHAPE).
const PART_SHAPE := [1.0, 1.0, 1.0]
const PARTS := {"back": [0], "chest": [1], "arms": [2, 3, 4, 5], "legs": [6, 7, 8, 9]}
## The way each region's limb runs at rest (none for the head: out from its middle).
const LIMB_AXES := [Vector3.UP, Vector3.UP, Vector3.RIGHT, Vector3.RIGHT, Vector3.LEFT, Vector3.LEFT, Vector3.DOWN,
	Vector3.DOWN, Vector3.DOWN, Vector3.DOWN, Vector3.FORWARD, Vector3.FORWARD, Vector3.FORWARD, Vector3.FORWARD,
	Vector3.FORWARD, Vector3.FORWARD, Vector3.ZERO]
## The spikes' own shape (each other than the triangle a model of its own, at the plain fur type:
## tools/build_raccoon.py `shape=`; the user: "why is there not any fur shape options beside triangle").
const SHAPES := ["triangle", "teardrop", "ribbon", "wavy", "curl", "blunt", "forked"]
## The bone each fur region (tools/build_raccoon.py REGION) grows on, and the way its fur lies back (at rest).
const REGION_BONES := [&"hips", &"chest", &"upper_arm_l", &"forearm_l", &"upper_arm_r", &"forearm_r", &"thigh_l",
	&"shin_l", &"thigh_r", &"shin_r", &"tail_0", &"tail_1", &"tail_2", &"tail_3", &"tail_4", &"tail_5", &"head"]
const REGION_AXES := [Vector3.DOWN, Vector3.DOWN, Vector3.RIGHT, Vector3.RIGHT, Vector3.LEFT, Vector3.LEFT,
	Vector3.DOWN, Vector3.DOWN, Vector3.DOWN, Vector3.DOWN, Vector3.FORWARD, Vector3.FORWARD, Vector3.FORWARD,
	Vector3.FORWARD, Vector3.FORWARD, Vector3.FORWARD, Vector3.FORWARD]
## A cat's markings (drawn from what tools/build_cat.py bakes into its vertex colours).
const PATTERNS := ["none", "tabby", "tuxedo", "calico", "bicolour", "tabby_white"]
const NAMES := {"spiky": "Spiky", "soft": "Soft", "shaggy": "Shaggy", "sleek": "Sleek", "wiry": "Wiry",
	"cones": "Tail cones", "plain": "Plain", "frosted": "Frosted tips", "dark_tips": "Dark tips",
	"streaked": "Streaked", "stippled": "Stippled", "none": "Solid", "tabby": "Tabby", "tuxedo": "Tuxedo",
	"calico": "Calico", "bicolour": "Patches", "tabby_white": "Tabby & white", "solid": "Solid", "straight": "Straight",
	"wavy": "Wavy", "curly": "Curly", "thick": "Thick",
	"triangle": "Triangle", "teardrop": "Teardrop", "ribbon": "Ribbon", "curl": "Curl", "blunt": "Blunt", "forked": "Forked"}
## The colours the editor offers, by material name, for each kind.
const COLOURS := {
	"raccoon": [["fur", "Fur"], ["light", "Light"], ["limb", "Legs"], ["tan", "Tail bands"], ["ring", "Tail rings"]],
	"cat": [["fur", "Fur"], ["light", "White"], ["stripe", "Stripes"], ["limb", "Legs"], ["eye", "Eyes"]],
}
## Surfaces that take the marks and markings (not eyes, nose, paws' pads).
const FURRY := ["fur", "light", "limb", "tan", "ring", "ear", "stripe", "paw", "dark"]

## The cats of the town, each a little different (Claude's picks; the user: "the cats need color variations ...
## different fur types"): a ginger tabby, a black, a grey long-hair, a tuxedo, a calico, a cream, a white.
const CAT_LOOKS := [
	{"fur": "spiky", "marks": "plain", "pattern": "tabby", "colours": {}},
	{"fur": "sleek", "marks": "frosted", "pattern": "none", "colours": {"fur": Color(0.09, 0.08, 0.09), "limb": Color(0.07, 0.06, 0.07), "stripe": Color(0.05, 0.05, 0.05), "light": Color(0.2, 0.19, 0.2), "eye": Color(0.95, 0.75, 0.15)}},
	{"fur": "shaggy", "marks": "streaked", "pattern": "tabby", "colours": {"fur": Color(0.52, 0.52, 0.55), "limb": Color(0.45, 0.45, 0.48), "stripe": Color(0.25, 0.25, 0.28), "light": Color(0.9, 0.9, 0.88), "eye": Color(0.35, 0.75, 0.85)}},
	{"fur": "soft", "marks": "plain", "pattern": "tuxedo", "colours": {"fur": Color(0.08, 0.07, 0.08), "limb": Color(0.08, 0.07, 0.08), "stripe": Color(0.05, 0.05, 0.05), "light": Color(0.96, 0.95, 0.92)}},
	{"fur": "sleek", "marks": "plain", "pattern": "calico", "colours": {"fur": Color(0.88, 0.5, 0.18), "limb": Color(0.86, 0.5, 0.2), "stripe": Color(0.1, 0.08, 0.08), "light": Color(0.97, 0.95, 0.9)}},
	{"fur": "soft", "marks": "stippled", "pattern": "tabby_white", "colours": {"fur": Color(0.93, 0.8, 0.6), "limb": Color(0.9, 0.77, 0.57), "stripe": Color(0.78, 0.58, 0.36), "eye": Color(0.45, 0.65, 0.95)}},
	{"fur": "shaggy", "marks": "plain", "pattern": "bicolour", "colours": {"fur": Color(0.96, 0.95, 0.92), "limb": Color(0.95, 0.94, 0.9), "stripe": Color(0.36, 0.3, 0.28), "light": Color(0.98, 0.97, 0.95)}},
]

static var _saved := {}
static var _loaded := false
static var _meshes := {}
static var _shader: Shader


## The model file for a kind ("raccoon", "cat") of fur type `fur`.
static func model_path(kind: String, fur: String, shape := "triangle") -> String:
	if kind == "raccoon" and shape in SHAPES and shape != "triangle":
		return "res://models/raccoon_shape_%s.glb" % shape
	if kind == "cat":
		return "res://models/cat.glb" if fur == "spiky" or not fur in CAT_TYPES else "res://models/cat_%s.glb" % fur
	return "res://models/raccoon.glb" if fur == "spiky" or not fur in TYPES else "res://models/raccoon_fur_%s.glb" % fur


static func kind_of(rig: Node) -> String:
	return "cat" if rig is CatRig else "raccoon"


## The fur shader's code: `code` (Toon's, with RaccoonRig's springing fur) shaping the spikes live (their length,
## angle, density and width at the root, the mane apart), drawing the marks, a cat's markings and Gloaming's hair
## textures too.
static func patterned(code: String) -> String:
	code = code.replace("uniform vec3 lags[17];", "uniform vec3 lags[17];\n" + _UNIFORMS)
	code = code.replace(_SPRUNG, _SHAPED)
	return code.replace(
			"ALBEDO = albedo * (1.0 - stripe * line) * mix(vec3(1.0), COLOR.rgb * GRIT_SCALE, COLOR.a);",
			"ALBEDO = fur_marked(fur_pattern(albedo, COLOR), UV2) * (1.0 - stripe * line) * fur_grit(COLOR);\n" + _STRANDED).replace(
			"void fragment() {", _FUNCTIONS + "\nvoid fragment() {")


## RaccoonRig's vertex stage (FUR_VERTEX), as patterned() takes it out.
const _SPRUNG := """void vertex() {
	if (UV2.y > 1.0005) {
		float flex = UV2.y - 1.001;
		int region = clamp(int(UV2.x + 0.5), 0, 16);
		VERTEX += lags[region] * flex * flex;
	}
}"""

## ...and what it puts in: the spring as before, after each spike is shaped (tools/build_raccoon.py tag_spikes: its
## group in UV2.x's tenths; its offset from its root in UV x, y and the colour's green; its rank, or which side of it
## the point is, in blue). `turns` turns a rest offset as its region's bone has turned.
const _SHAPED := """varying float fur_along;
varying float fur_across;
varying float fur_seed;
void vertex() {
	fur_along = -1.0;
	fur_across = 0.5;
	fur_seed = 0.0;
	if (UV2.y > 1.0005) {
		float flex = UV2.y - 1.001;
		int region = clamp(int(UV2.x + 0.5), 0, 16);
		int group = int(round(fract(UV2.x) * 10.0));
		// (a spike's tip; on a lock (a fur shape) every point out from its root)
		bool tipped = locks ? flex > 0.0 : flex > 0.99;
		fur_along = flex;
		// (across a spike: a tip is in the middle; the points either side of it, and its roots, are one side or the other)
		fur_across = tipped ? 0.5 : (masked ? UV.x : COLOR.b);
		fur_seed = float(region) * 7.0 + float(group);
		// (at the bending joints, elbows and knees, the fur springs half as far)
		float give = (region == 3 || region == 5 || region == 7 || region == 9) ? 0.5 : 1.0;
		vec3 lag = lags[region] * flex * flex * give;
		if (kept && group <= 2) {
			mat3 turn = turns[region];
			// (glTF flips V: the y offset comes as 1 - y)
			vec3 now = turn * vec3(UV.x, 1.0 - UV.y, (COLOR.g - 0.5) * 0.5);
			vec3 root = VERTEX - now;
			vec3 off = now;
			if (shaped) {
				// (length, angle, density, width: all of it, times its part's size, width and density)
				vec4 fur = group == 1 ? mane_fur : body_fur;
				vec4 part = group == 2 ? crown_fur : (group == 0 ? part_fur[region] : vec4(1.0));
				fur.x *= part.x;
				fur.w *= part.y;
				fur.z *= part.z;
				off = now * fur.w;
				if (flex > 0.0) {
					float len = length(now) * fur.x;
					vec3 dir = len > 0.0001 ? normalize(now) : vec3(0.0, 1.0, 0.0);
					if (abs(fur.y) > 0.0001) {
						vec3 axis = normalize(turn * axes[region]);
						float c = dot(dir, axis);
						vec3 side = dir - axis * c;
						float s = length(side);
						if (s > 0.001) {
							float c2 = clamp(c + fur.y, -0.3, 0.95);
							dir = axis * c2 + side / s * sqrt(1.0 - c2 * c2);
						}
					}
					off = tipped && COLOR.b > fur.z ? vec3(0.0) : dir * len;
				}
			}
			if (flex > 0.0) {
				off += lag;
				// Kept out of his body (the user, 2026-11-02: "they clip into the body a lot"): never closer to the
				// surface at its root than a little way out from it. Out is from the limb's line (the body, arms
				// and legs) or the head's middle (the mane and crown).
				vec3 away = root - origins[group == 0 ? region : 16];
				vec3 limb = limbs[region];
				if (group == 0 && dot(limb, limb) > 0.25) {
					away -= limb * dot(away, limb);
				}
				away = dot(away, away) > 0.00000001 ? normalize(away) : vec3(0.0, 1.0, 0.0);
				float rise = dot(off, away);
				float least = 0.15 * length(off);
				if (rise < least) {
					off += away * (least - rise);
				}
			}
			VERTEX = root + off;
		} else if (kept && group == 3) {
			// (the tail, its skin and its cones: out from its line by how thick it is, less what its length made it)
			vec3 now = turns[region] * vec3(UV.x, 1.0 - UV.y, (COLOR.g - 0.5) * 0.5);
			VERTEX += now * (tail_girth - 1.0) + lag;
		} else {
			VERTEX += lag;
		}
	}
}"""

## Gloaming's hair textures on the fur (its hair_locks shader's strands, as a game's hair cards are): fine strands down
## each spike, see-through between them, each its own shade, dense at the root and thinning to the tip.
const _STRANDED := """	if (furry && texture > 0 && fur_along >= 0.0) {
		float shade;
		float strand_edge;
		float cover = fur_strands(fur_across, fur_along, fur_seed, shade, strand_edge);
		cover = max(cover, 1.0 - smoothstep(0.0, 0.16, fur_along));
		if (cover < 0.05 + fur_dither(FRAGCOORD.xy) * 0.6) {
			discard;
		}
		ALBEDO *= (0.68 + 0.6 * shade) * strand_edge * mix(0.62, 1.08, smoothstep(0.0, 0.7, fur_along));
	}"""


const _UNIFORMS := """
// (FurLook: the marks and markings)
uniform bool furry = false;
uniform bool masked = false;
uniform int marks = 0;
uniform int pattern = 0;
uniform vec3 white_colour : source_color = vec3(0.96, 0.94, 0.9);
uniform vec3 dark_colour : source_color = vec3(0.1, 0.09, 0.1);
// (shaping: length, angle, density, width at the root; the body's and the mane's)
uniform bool shaped = false;
uniform mat3 turns[17];
uniform vec3 axes[17];
uniform vec4 body_fur = vec4(1.0, 0.0, 1.0, 1.0);
uniform vec4 mane_fur = vec4(1.0, 0.0, 1.0, 1.0);
// (each part's size, width, density: by region, and the crown's)
uniform vec4 part_fur[17];
uniform vec4 crown_fur = vec4(1.0, 1.0, 1.0, 0.0);
// (kept out of the body: each region's bone where it is now, and the way its limb runs)
uniform bool kept = false;
uniform vec3 origins[17];
uniform vec3 limbs[17];
// (the spikes are locks: a fur shape, every point out from its root a part of it)
uniform bool locks = false;
// (how thick the tail is, over what its length makes it)
uniform float tail_girth = 1.0;
// (Gloaming's hair textures: TEXTURES)
uniform int texture = 0;
"""

const _FUNCTIONS := """
// A spike's tag (its region, how far out along it), or -1 off the spikes; and where on a part (in metres) elsewhere.
float fur_flex(vec2 uv2) { return uv2.y > 1.0005 ? uv2.y - 1.001 : -1.0; }
float fur_hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
vec3 fur_grit(vec4 tint) {
	// (a cat's vertex colours hold its markings, its grit in red only)
	// (his, its red only: green and blue shape the spikes)
	if (masked) { return vec3(tint.r * GRIT_SCALE); }
	return mix(vec3(1.0), vec3(tint.r) * GRIT_SCALE, tint.a);
}
float fur_dither(vec2 at) {
	return fract(52.9829189 * fract(dot(at, vec2(0.06711056, 0.00583715))));
}
// (Gloaming's strands(): how much of this point is hair, the strand's own shade and its edge's darkening)
float fur_strands(float across01, float along, float seed, out float shade, out float strand_edge) {
	float n = texture == 5 ? 4.0 : (texture == 4 ? 7.0 : (texture == 3 ? 9.0 : 13.0));
	float q0 = across01 * n;
	float h = fur_hash(vec2(floor(q0), seed * 31.0));
	float run = along * 12.0;
	float q = q0;
	if (texture == 2) {
		q += sin(run * 1.2 + seed * 6.28) * 2.4 + sin(run * 3.1 + h * 6.28) * 0.15;
	} else if (texture == 3) {
		q += sin(run * 4.2 + h * 6.28) * 1.1 + sin(run * 9.5 + h * 3.0) * 0.3;
	} else if (texture == 4) {
		q += sin(run * 0.9 + h * 6.28) * 0.35;
	}
	float own = fur_hash(vec2(floor(q), seed * 31.0 + 7.0));
	shade = own;
	float d = abs(fract(q) - 0.5) * 2.0;
	float thick = texture == 5 ? 0.78 : (texture == 4 ? 1.0 : 0.66);
	float hair = 1.0 - smoothstep(thick - 0.06, thick + 0.06, d);
	strand_edge = mix(1.0, texture == 4 ? 0.85 : 0.55, smoothstep(0.15, thick, d));
	if (texture == 4) {
		hair = (1.0 - smoothstep(0.0, 1.0, d)) * 0.92;
	}
	float ends = 1.0 - smoothstep(0.7 + 0.28 * own - 0.04, 0.7 + 0.28 * own, along);
	return hair * ends;
}
vec3 fur_pattern(vec3 base, vec4 tint) {
	if (!furry || !masked || pattern == 0) { return base; }
	float w_mask = smoothstep(0.42, 0.58, tint.g);
	float blot = tint.b;
	float s_mask = smoothstep(0.55, 0.7, tint.a);
	if (pattern == 1) { return mix(base, dark_colour, s_mask * 0.85); }
	if (pattern == 2) { return mix(base, white_colour, w_mask); }
	if (pattern == 3) {
		vec3 c = mix(base, dark_colour, smoothstep(0.6, 0.66, blot));
		return mix(c, white_colour, max(w_mask, smoothstep(0.36, 0.3, blot)));
	}
	if (pattern == 4) { return mix(base, dark_colour, smoothstep(0.62, 0.68, blot) * (1.0 - w_mask)); }
	if (pattern == 5) { return mix(mix(base, dark_colour, s_mask * 0.85), white_colour, w_mask); }
	return base;
}
vec3 fur_marked(vec3 colour, vec2 uv2) {
	if (!furry || marks == 0) { return colour; }
	float flex = fur_flex(uv2);
	if (marks == 1) { return flex >= 0.0 ? mix(colour, vec3(1.0), 0.55 * flex * flex) : colour; }
	if (marks == 2) { return flex >= 0.0 ? colour * (1.0 - 0.7 * flex * flex) : colour * 0.9; }
	if (marks == 3) {
		// (fine streaks along the fur: round the parts on the bodies, by a spike's tip on the fur)
		float s = flex >= 0.0 ? fur_hash(vec2(uv2.x, floor(flex * 3.0))) : fur_hash(vec2(floor((1.0 - uv2.y) * 160.0), 0.5));
		return colour * (0.8 + 0.32 * s);
	}
	if (marks == 4) {
		float d = flex >= 0.0 ? fur_hash(vec2(uv2.x * 7.0 + flex * 9.0, flex)) : fur_hash(floor(vec2(uv2.x, 1.0 - uv2.y) * 90.0));
		return colour * (d > 0.8 ? 0.62 : 1.0);
	}
	return colour;
}
"""


## Puts the fur type's mesh on the rig's figure (from rig.look "fur"), before it is shaded. The figure's own mesh is
## kept to go back to.
static func swap(rig: RaccoonRig) -> void:
	if rig._figure == null:
		return
	var fur: String = rig.look.get("fur", "")
	var shape: String = rig.look.get("shape", "triangle")
	var meshes := rig._figure.find_children("*", "MeshInstance3D", true, false)
	if meshes.is_empty():
		return
	var part := meshes[0] as MeshInstance3D
	if not part.has_meta(&"own_mesh"):
		part.set_meta(&"own_mesh", part.mesh)
		part.set_meta(&"own_skin", part.skin)
	if fur == "" and shape == "triangle":
		return
	var path := model_path(kind_of(rig), fur if fur != "" else "spiky", shape)
	if not _meshes.has(path):
		if not ResourceLoader.exists(path):
			return
		var scene := (load(path) as PackedScene).instantiate()
		var found := scene.find_children("*", "MeshInstance3D", true, false)
		_meshes[path] = [found[0].mesh, found[0].skin] if not found.is_empty() else []
		scene.free()
	var taken: Array = _meshes[path]
	if taken.is_empty():
		return
	part.mesh = taken[0]
	part.skin = taken[1]


## Sets what is drawn on the fur (the look's marks, pattern and white and dark colours) on every fur material.
static func paint(rig: RaccoonRig) -> void:
	if rig._figure == null:
		return
	var look: Dictionary = rig.look
	var colours: Dictionary = look.get("colours", {})
	var masked := kind_of(rig) == "cat"
	var shapes := _shapes(rig)
	var body: Array = shapes[0]
	var mane: Array = shapes[1]
	var shaped: bool = shapes[2]
	# (kept out of his body always: only his models carry each spike's root, a cat's colours are its markings)
	var kept := kind_of(rig) == "raccoon"
	for part: MeshInstance3D in rig._figure.find_children("*", "MeshInstance3D", true, false):
		if part.mesh == null:
			continue
		for surface in part.mesh.get_surface_count():
			var material := part.get_surface_override_material(surface) as ShaderMaterial
			var original := part.mesh.surface_get_material(surface)
			if material == null or original == null:
				continue
			var named := original.resource_name
			material.set_shader_parameter(&"furry", named in FURRY)
			material.set_shader_parameter(&"masked", masked)
			material.set_shader_parameter(&"marks", maxi(MARKS.find(look.get("marks", "plain")), 0))
			material.set_shader_parameter(&"pattern", maxi(PATTERNS.find(look.get("pattern", "none")), 0))
			material.set_shader_parameter(&"white_colour", colours.get("light", Color(0.96, 0.94, 0.9)))
			material.set_shader_parameter(&"dark_colour", colours.get("stripe", Color(0.42, 0.18, 0.07)))
			material.set_shader_parameter(&"texture", maxi(TEXTURES.find(look.get("texture", "solid")), 0))
			material.set_shader_parameter(&"shaped", shaped)
			material.set_shader_parameter(&"body_fur", Vector4(body[0], body[1], body[2], 1.0))
			material.set_shader_parameter(&"mane_fur", Vector4(mane[0], mane[1], mane[2], mane[3]))
			material.set_shader_parameter(&"axes", PackedVector3Array(REGION_AXES))
			material.set_shader_parameter(&"part_fur", shapes[3])
			material.set_shader_parameter(&"crown_fur", shapes[4])
			material.set_shader_parameter(&"kept", kept)
			material.set_shader_parameter(&"locks", look.get("shape", "triangle") != "triangle")
			var tail_shape: Array = look.get("tail", TAIL_SHAPE)
			material.set_shader_parameter(&"tail_girth", float(tail_shape[1]) / maxf(float(tail_shape[0]), 0.01))
	rig.set_meta(&"shaped", shaped)
	rig.set_meta(&"kept", kept)
	if kept:
		shape(rig)
	var tail: Array = look.get("tail", TAIL_SHAPE)
	rig.tail_length = float(tail[0])
	rig.tail_thickness = float(tail[1])


## The fur's shape from the look: the body's and the mane's (their defaults where it has none), and whether it is
## shaped at all (only his models carry what it takes: a cat's colours are its markings).
static func _shapes(rig: RaccoonRig) -> Array:
	var look: Dictionary = rig.look
	var body: Array = look.get("body", BODY_SHAPE)
	var mane: Array = look.get("mane", MANE_SHAPE)
	var parts: Dictionary = look.get("parts", {})
	var crown: Array = parts.get("crown", PART_SHAPE)
	var by_region := []
	by_region.resize(REGION_BONES.size())
	by_region.fill(Vector4(1.0, 1.0, 1.0, 0.0))
	var custom := false
	for named: String in PARTS:
		var made: Array = parts.get(named, PART_SHAPE)
		custom = custom or made != PART_SHAPE
		for region: int in PARTS[named]:
			by_region[region] = Vector4(made[0], made[1], made[2], 0.0)
	custom = custom or crown != PART_SHAPE
	var shaped := kind_of(rig) == "raccoon" and (body != BODY_SHAPE or mane != MANE_SHAPE or custom)
	return [body, mane, shaped, by_region, Vector4(crown[0], crown[1], crown[2], 0.0)]


## Each frame, while the fur is shaped: how each region's bone has turned from rest, for the shader to lay the
## spikes' rest offsets by.
static func shape(rig: RaccoonRig) -> void:
	if not rig.get_meta(&"kept", false) or rig._skeleton == null:
		return
	var skeleton: Skeleton3D = rig._skeleton
	var turns := []
	var origins := PackedVector3Array()
	var limbs := PackedVector3Array()
	for k in REGION_BONES.size():
		var index := skeleton.find_bone(REGION_BONES[k])
		var turn := Basis.IDENTITY
		var at := Vector3.ZERO
		if index >= 0:
			var pose := skeleton.get_bone_global_pose(index)
			turn = (pose * skeleton.get_bone_global_rest(index).affine_inverse()).basis
			at = pose.origin
		turns.append(turn)
		origins.append(at)
		limbs.append((turn * LIMB_AXES[k]).normalized() if LIMB_AXES[k] != Vector3.ZERO else Vector3.ZERO)
	for material in rig._fur_materials:
		material.set_shader_parameter(&"turns", turns)
		material.set_shader_parameter(&"origins", origins)
		material.set_shader_parameter(&"limbs", limbs)


# --- Kept looks ---

static func _load() -> void:
	if _loaded:
		return
	_loaded = true
	if not FileAccess.file_exists(FILE):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(FILE))
	if parsed is Dictionary:
		_saved = parsed


static func _save() -> void:
	var file := FileAccess.open(FILE, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(_saved, "  "))


## The hero's look as last made in the editor ({} for his own).
static func hero() -> Dictionary:
	_load()
	return _decode(_saved.get("hero", {}))


static func set_hero(look: Dictionary) -> void:
	_load()
	_saved["hero"] = _encode(look)
	_save()


## Cat number `index`'s look: as made in the editor, or its own of CAT_LOOKS.
static func cat(index: int) -> Dictionary:
	_load()
	var cats: Dictionary = _saved.get("cats", {})
	if cats.has(str(index)):
		return _decode(cats[str(index)])
	return (CAT_LOOKS[index % CAT_LOOKS.size()] as Dictionary).duplicate(true)


static func set_cat(index: int, look: Dictionary) -> void:
	_load()
	var cats: Dictionary = _saved.get("cats", {})
	cats[str(index)] = _encode(look)
	_saved["cats"] = cats
	_save()


## Forgets what the editor made: back to their own looks.
static func forget(kind: String, index := 0) -> void:
	_load()
	if kind == "cat":
		var cats: Dictionary = _saved.get("cats", {})
		cats.erase(str(index))
		_saved["cats"] = cats
	else:
		_saved.erase("hero")
	_save()


static func _encode(look: Dictionary) -> Dictionary:
	var out := look.duplicate(true)
	var colours := {}
	for key: String in look.get("colours", {}):
		colours[key] = (look["colours"][key] as Color).to_html(false)
	out["colours"] = colours
	return out


static func _decode(saved: Dictionary) -> Dictionary:
	var out := saved.duplicate(true)
	var colours := {}
	for key: String in saved.get("colours", {}):
		colours[key] = Color.html(saved["colours"][key])
	if not saved.is_empty():
		out["colours"] = colours
	return out
