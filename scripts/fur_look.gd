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
## A cat's markings (drawn from what tools/build_cat.py bakes into its vertex colours).
const PATTERNS := ["none", "tabby", "tuxedo", "calico", "bicolour", "tabby_white"]
const NAMES := {"spiky": "Spiky", "soft": "Soft", "shaggy": "Shaggy", "sleek": "Sleek", "wiry": "Wiry",
	"cones": "Tail cones", "plain": "Plain", "frosted": "Frosted tips", "dark_tips": "Dark tips",
	"streaked": "Streaked", "stippled": "Stippled", "none": "Solid", "tabby": "Tabby", "tuxedo": "Tuxedo",
	"calico": "Calico", "bicolour": "Patches", "tabby_white": "Tabby & white"}
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
static func model_path(kind: String, fur: String) -> String:
	if kind == "cat":
		return "res://models/cat.glb" if fur == "spiky" or not fur in CAT_TYPES else "res://models/cat_%s.glb" % fur
	return "res://models/raccoon.glb" if fur == "spiky" or not fur in TYPES else "res://models/raccoon_fur_%s.glb" % fur


static func kind_of(rig: Node) -> String:
	return "cat" if rig is CatRig else "raccoon"


## The fur shader's code: `code` (Toon's, with RaccoonRig's springing fur) drawing the marks and markings too.
static func patterned(code: String) -> String:
	code = code.replace("uniform vec3 lags[17];", "uniform vec3 lags[17];\n" + _UNIFORMS)
	return code.replace(
			"ALBEDO = albedo * (1.0 - stripe * line) * mix(vec3(1.0), COLOR.rgb * GRIT_SCALE, COLOR.a);",
			"ALBEDO = fur_marked(fur_pattern(albedo, COLOR), UV2) * (1.0 - stripe * line) * fur_grit(COLOR);").replace(
			"void fragment() {", _FUNCTIONS + "\nvoid fragment() {")


const _UNIFORMS := """
// (FurLook: the marks and markings)
uniform bool furry = false;
uniform bool masked = false;
uniform int marks = 0;
uniform int pattern = 0;
uniform vec3 white_colour : source_color = vec3(0.96, 0.94, 0.9);
uniform vec3 dark_colour : source_color = vec3(0.1, 0.09, 0.1);
"""

const _FUNCTIONS := """
// A spike's tag (its region, how far out along it), or -1 off the spikes; and where on a part (in metres) elsewhere.
float fur_flex(vec2 uv2) { return uv2.y > 1.0005 ? uv2.y - 1.001 : -1.0; }
float fur_hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
vec3 fur_grit(vec4 tint) {
	// (a cat's vertex colours hold its markings, its grit in red only)
	if (masked) { return vec3(tint.r * GRIT_SCALE); }
	return mix(vec3(1.0), tint.rgb * GRIT_SCALE, tint.a);
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
	var meshes := rig._figure.find_children("*", "MeshInstance3D", true, false)
	if meshes.is_empty():
		return
	var part := meshes[0] as MeshInstance3D
	if not part.has_meta(&"own_mesh"):
		part.set_meta(&"own_mesh", part.mesh)
		part.set_meta(&"own_skin", part.skin)
	if fur == "":
		return
	var path := model_path(kind_of(rig), fur)
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
