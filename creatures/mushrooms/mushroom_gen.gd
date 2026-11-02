@tool
class_name MushroomGen
extends Resource
## Any mushroom, built from code (after the tree component's TreeGen): a stem that may swell to a bulb at its foot and
## wear a ring, a cap of one of a few shapes (convex, flat, bell, funnel, conical, a shelf off a wall, a puffball's
## ball, a morel's pitted cone), gills under it, spots or warts on it, in a cluster of several leaning out from the
## middle. Low poly (a few hundred triangles a mushroom: Ringtail, 2026-11-02, "we also need a mushroom generator",
## after "decently low poly, Twilight Princess-esque"), vertex coloured, drawn with MushroomLook's shader (so they glow
## at night if asked, and sway and squash as the patch's do). The same settings and seed always make the same cluster.
##
## One:    var g := MushroomGen.preset("Fly agaric"); g.seed = 3; var mesh := g.mesh()
## Many:   MushroomGen.scatter(parent, transforms, g, 3)   (a MultiMesh per variant: a few draws, drawn only near)
##
## The mesh's foot is at the origin, up +Y (a shelf grows out along +Z from its back at z 0, as MushroomPatch's
## brackets do). Every vertex carries an sRGB colour, UV.x how much it glows (MushroomLook GLOW), UV.y how far up it
## is (0..1: how much it sways).

enum Cap { CONVEX, FLAT, BELL, FUNNEL, CONICAL, SHELF, BALL, MOREL }

## The cap shapes' top surfaces from the middle out to the rim: (radius, height), each 0..1 of the cap's.
const PROFILES := {
	Cap.CONVEX: [Vector2(0.0, 1.0), Vector2(0.45, 0.92), Vector2(0.78, 0.68), Vector2(0.97, 0.3), Vector2(0.93, 0.0)],
	Cap.FLAT: [Vector2(0.0, 1.0), Vector2(0.5, 0.97), Vector2(0.85, 0.8), Vector2(1.0, 0.4), Vector2(0.97, 0.0)],
	Cap.BELL: [Vector2(0.0, 1.0), Vector2(0.32, 0.94), Vector2(0.62, 0.72), Vector2(0.86, 0.36), Vector2(1.0, 0.0)],
	Cap.FUNNEL: [Vector2(0.0, 0.25), Vector2(0.4, 0.5), Vector2(0.78, 0.86), Vector2(1.0, 1.0), Vector2(0.98, 0.82)],
	Cap.CONICAL: [Vector2(0.0, 1.0), Vector2(0.3, 0.7), Vector2(0.62, 0.38), Vector2(0.9, 0.1), Vector2(1.0, 0.0)],
	Cap.SHELF: [Vector2(0.0, 0.7), Vector2(0.45, 1.0), Vector2(0.8, 0.8), Vector2(1.0, 0.35), Vector2(0.98, 0.0)],
	Cap.BALL: [Vector2(0.0, 1.0), Vector2(0.55, 0.93), Vector2(0.9, 0.7), Vector2(1.0, 0.42), Vector2(0.85, 0.12), Vector2(0.45, 0.0)],
	Cap.MOREL: [Vector2(0.0, 1.0), Vector2(0.38, 0.85), Vector2(0.68, 0.6), Vector2(0.88, 0.32), Vector2(1.0, 0.08), Vector2(0.92, 0.0)],
}

const PRESETS := {
	"Fly agaric": {cap_shape = Cap.CONVEX, cap_radius = 0.09, cap_height = 0.055, stem_height = 0.16, stem_radius = 0.018,
			bulb = 0.9, ring = 0.7, spots = 14, spot_size = 0.18, cap_colour = Color(0.86, 0.12, 0.08),
			rim_colour = Color(0.95, 0.42, 0.12), stem_colour = Color(0.95, 0.92, 0.84), gill_colour = Color(0.96, 0.94, 0.86),
			spot_colour = Color(0.98, 0.96, 0.9), count = 3, spread = 0.12},
	"Porcini": {cap_shape = Cap.CONVEX, cap_radius = 0.085, cap_height = 0.06, stem_height = 0.09, stem_radius = 0.032,
			bulb = 1.2, cap_colour = Color(0.45, 0.25, 0.12), rim_colour = Color(0.62, 0.42, 0.22),
			stem_colour = Color(0.88, 0.8, 0.62), gill_colour = Color(0.82, 0.78, 0.5), gills = false, count = 2, spread = 0.1},
	"Chanterelle": {cap_shape = Cap.FUNNEL, cap_radius = 0.045, cap_height = 0.03, stem_height = 0.05, stem_radius = 0.013,
			stem_taper = 1.8, cap_colour = Color(0.98, 0.7, 0.18), rim_colour = Color(1.0, 0.8, 0.32),
			stem_colour = Color(0.96, 0.74, 0.26), gill_colour = Color(0.94, 0.66, 0.2), count = 5, spread = 0.12, lean = 0.3},
	"Inkcap": {cap_shape = Cap.BELL, cap_radius = 0.028, cap_height = 0.1, stem_height = 0.13, stem_radius = 0.009,
			ring = 0.25, cap_colour = Color(0.9, 0.88, 0.82), rim_colour = Color(0.2, 0.19, 0.22),
			stem_colour = Color(0.95, 0.94, 0.9), gill_colour = Color(0.15, 0.14, 0.16), warts = 10, spot_size = 0.25,
			spot_colour = Color(0.72, 0.62, 0.5), count = 4, spread = 0.07, lean = 0.12},
	"Honey cluster": {cap_shape = Cap.CONVEX, cap_radius = 0.035, cap_height = 0.018, stem_height = 0.1, stem_radius = 0.007,
			ring = 0.8, cap_colour = Color(0.78, 0.52, 0.18), rim_colour = Color(0.9, 0.7, 0.36),
			stem_colour = Color(0.86, 0.74, 0.52), gill_colour = Color(0.92, 0.84, 0.66), warts = 6, spot_size = 0.12,
			spot_colour = Color(0.45, 0.3, 0.14), count = 11, spread = 0.07, lean = 0.5, segments = 8},
	"Oyster shelves": {cap_shape = Cap.SHELF, cap_radius = 0.08, cap_height = 0.022, stem_height = 0.0,
			cap_colour = Color(0.62, 0.62, 0.6), rim_colour = Color(0.78, 0.77, 0.74), gill_colour = Color(0.9, 0.88, 0.82),
			count = 4, spread = 0.12},
	"Bracket": {cap_shape = Cap.SHELF, cap_radius = 0.12, cap_height = 0.03, stem_height = 0.0, gills = false,
			cap_colour = Color(0.36, 0.24, 0.14), rim_colour = Color(0.9, 0.78, 0.5), gill_colour = Color(0.92, 0.86, 0.68),
			bands = 0.6, count = 3, spread = 0.16},
	"Puffball": {cap_shape = Cap.BALL, cap_radius = 0.08, cap_height = 0.12, stem_height = 0.0, gills = false,
			cap_colour = Color(0.94, 0.92, 0.84), rim_colour = Color(0.86, 0.82, 0.7), warts = 16, spot_size = 0.08,
			spot_colour = Color(0.98, 0.97, 0.92), count = 2, spread = 0.12},
	"Morel": {cap_shape = Cap.MOREL, cap_radius = 0.03, cap_height = 0.08, stem_height = 0.05, stem_radius = 0.016,
			stem_taper = 0.85, gills = false, pits = 1.0, cap_colour = Color(0.48, 0.36, 0.22), rim_colour = Color(0.62, 0.5, 0.32),
			stem_colour = Color(0.9, 0.84, 0.7), count = 2, spread = 0.07},
	"Mycena": {cap_shape = Cap.CONICAL, cap_radius = 0.012, cap_height = 0.012, stem_height = 0.06, stem_radius = 0.0025,
			cap_colour = Color(0.62, 0.52, 0.48), rim_colour = Color(0.82, 0.76, 0.7), stem_colour = Color(0.88, 0.84, 0.8),
			gill_colour = Color(0.92, 0.9, 0.86), count = 16, spread = 0.09, lean = 0.4, segments = 6},
	"Foxfire bonnets": {cap_shape = Cap.BELL, cap_radius = 0.022, cap_height = 0.03, stem_height = 0.11, stem_radius = 0.004,
			cap_colour = Color(0.78, 0.86, 0.72), rim_colour = Color(0.9, 0.95, 0.84), stem_colour = Color(0.84, 0.9, 0.8),
			gill_colour = Color(0.9, 0.96, 0.86), glow = 1.0, count = 7, spread = 0.07, lean = 0.3, segments = 7},
}

@export var seed := 1
@export_group("Cap")
@export var cap_shape := Cap.CONVEX
## The cap's radius and height (metres, at size 1).
@export_range(0.005, 0.5, 0.001, "or_greater") var cap_radius := 0.06
@export_range(0.003, 0.5, 0.001, "or_greater") var cap_height := 0.04
## Its colour in the middle and at the rim; rings of the two in turn (a bracket's growth bands), 0 none.
@export var cap_colour := Color(0.6, 0.4, 0.25)
@export var rim_colour := Color(0.75, 0.55, 0.35)
@export_range(0.0, 1.0) var bands := 0.0
## Gills under it (radial fins), and their colour (also the underside's when there are none: pores).
@export var gills := true
@export var gill_colour := Color(0.9, 0.85, 0.75)
## Raised spots (flat patches) and warts (little points) on the cap, how big (of the cap's radius), their colour.
@export_range(0, 40) var spots := 0
@export_range(0, 40) var warts := 0
@export_range(0.03, 0.4) var spot_size := 0.15
@export var spot_colour := Color(0.97, 0.95, 0.9)
## A morel's pits: the cap's points pushed in and darkened in a honeycomb (0 none).
@export_range(0.0, 1.0) var pits := 0.0
@export_group("Stem")
## The stem's height (0: none: a shelf or a puffball), its radius, how much narrower at the top than the foot
## (1 the same; over 1 wider at the top: a chanterelle's), a bulb at its foot, a ring (skirt) at this fraction up
## (0 none), its colour.
@export_range(0.0, 0.6, 0.001, "or_greater") var stem_height := 0.1
@export_range(0.001, 0.2, 0.001, "or_greater") var stem_radius := 0.012
@export_range(0.3, 2.5) var stem_taper := 0.8
@export_range(0.0, 2.0) var bulb := 0.0
@export_range(0.0, 0.95) var ring := 0.0
@export var stem_colour := Color(0.92, 0.88, 0.8)
@export_group("Cluster")
## How many, how far apart (metres from the middle), how much the outer ones lean out (radians at the edge), how
## much each one's size varies.
@export_range(1, 30) var count := 1
@export_range(0.0, 0.5) var spread := 0.08
@export_range(0.0, 1.0) var lean := 0.2
@export_range(0.0, 0.8) var size_random := 0.3
## How much each one's colours wander (hue and value), so a cluster is not all one.
@export_range(0.0, 0.3) var colour_random := 0.06
@export_group("Look")
## How much the caps glow at night (MushroomLook: foxfire), 0..1.
@export_range(0.0, 1.0) var glow := 0.0
## Points round each ring (fewer for small ones).
@export_range(5, 16) var segments := 10

var _rng := RandomNumberGenerator.new()
var _st: SurfaceTool
var _total_height := 1.0
var _hue := 0.0
var _value := 1.0

static var _cache := {}


static func names() -> Array:
	return PRESETS.keys()


## A generator set as one of PRESETS (any setting can then be changed).
static func preset(name: String) -> MushroomGen:
	var made := MushroomGen.new()
	var settings: Dictionary = PRESETS.get(name, {})
	for key: String in settings:
		made.set(key, settings[key])
	return made


## The cluster's mesh (vertex coloured, one surface, MushroomLook's shared material on it). `low`: fewer points.
func mesh(low := false) -> ArrayMesh:
	_rng.seed = seed
	_st = SurfaceTool.new()
	_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var ring_points := maxi(segments - (3 if low else 0), 5)
	_total_height = maxf(stem_height + cap_height, 0.01) * (1.0 + size_random)
	var shelf := cap_shape == Cap.SHELF
	for k in count:
		# (the middle ones biggest, leaning out more the further out they stand; shelves stack up a wall instead)
		var out := 0.0 if k == 0 else sqrt(_rng.randf()) * spread
		var round_about := _rng.randf() * TAU
		var size := (1.0 + _rng.randf_range(-size_random, size_random)) * (1.0 - 0.3 * out / maxf(spread, 0.001))
		var where: Transform3D
		if shelf:
			var up := float(k) * cap_radius * 0.75 + _rng.randf_range(0.0, cap_radius * 0.3)
			var aside := _rng.randf_range(-spread, spread) * 0.6 if k > 0 else 0.0
			where = Transform3D(Basis(Vector3.UP, _rng.randf_range(-0.35, 0.35)).scaled(Vector3.ONE * size * (1.0 - 0.12 * k)), Vector3(aside, up, 0.0))
		else:
			var tilt := lean * out / maxf(spread, 0.001) + _rng.randf_range(0.0, 0.08)
			var axis := Vector3(-sin(round_about), 0.0, cos(round_about))
			where = Transform3D((Basis(axis, tilt) * Basis(Vector3.UP, _rng.randf() * TAU)).scaled(Vector3.ONE * size),
					Vector3(cos(round_about), 0.0, sin(round_about)) * out)
		_one(where, ring_points if size > 0.75 or count < 4 else maxi(ring_points - 2, 5))
	_st.index()
	_st.generate_normals()
	var made := _st.commit()
	made.surface_set_material(0, MushroomLook.shared())
	_st = null
	return made


## Mushrooms at `places` (transforms in `parent`'s space: foot, up, size), `variants` meshes of `gen` (seeds gen.seed,
## +1, ...) each one MultiMesh drawn only within `far` m. Returns the MultiMeshInstance3Ds made (children of `parent`).
static func scatter(parent: Node3D, places: Array, gen: MushroomGen, variants := 3, far := 45.0, low := false) -> Array[MultiMeshInstance3D]:
	var made: Array[MultiMeshInstance3D] = []
	var lists: Array = []
	for v in variants:
		lists.append([])
	for i in places.size():
		(lists[i % variants] as Array).append(places[i])
	for v in variants:
		var list: Array = lists[v]
		if list.is_empty():
			continue
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.use_custom_data = true
		# (and colours, all white: without them a MultiMesh loses the vertex colours in GL Compatibility)
		multi.use_colors = true
		multi.mesh = gen.variant(v, low)
		multi.instance_count = list.size()
		for i in list.size():
			multi.set_instance_transform(i, list[i])
			multi.set_instance_custom_data(i, Color(0.0, 0.15, randf(), 0.0))
			multi.set_instance_color(i, Color.WHITE)
		var shown := MultiMeshInstance3D.new()
		shown.multimesh = multi
		shown.material_override = MushroomLook.shared()
		shown.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		shown.visibility_range_end = far
		shown.visibility_range_end_margin = 6.0
		shown.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		parent.add_child(shown)
		made.append(shown)
	return made


## Its mesh with seed + `offset` (made once, then shared).
func variant(offset: int, low := false) -> ArrayMesh:
	var key := "%s|%d|%s" % [var_to_str(_settings()), seed + offset, low]
	if not _cache.has(key):
		var was := seed
		seed = was + offset
		_cache[key] = mesh(low)
		seed = was
	return _cache[key]


func _settings() -> Array:
	return [cap_shape, cap_radius, cap_height, cap_colour, rim_colour, bands, gills, gill_colour, spots, warts, spot_size,
			spot_colour, pits, stem_height, stem_radius, stem_taper, bulb, ring, stem_colour, count, spread, lean,
			size_random, colour_random, glow, segments]


## One mushroom at `where` (in the cluster).
func _one(where: Transform3D, around: int) -> void:
	_hue = _rng.randf_range(-colour_random, colour_random) * 0.4
	_value = 1.0 + _rng.randf_range(-colour_random, colour_random) * 2.0
	var shelf := cap_shape == Cap.SHELF
	var r := cap_radius
	var h := cap_height
	var stem_h := stem_height * _rng.randf_range(0.85, 1.15)
	var arc := [-PI * 0.5, PI * 0.5] if shelf else [0.0, TAU]
	# The stem: rings up from its foot (a bulb swelling there), a little crooked
	if stem_h > 0.0 and not shelf:
		var rings: Array = []
		var crook := Vector2(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-1.0, 1.0)) * stem_radius * 0.8
		var steps := 5 if bulb > 0.0 else 3
		for i in steps + 1:
			var t := float(i) / steps
			var radius := stem_radius * lerpf(1.0, stem_taper, t) * (1.0 + bulb * pow(1.0 - t, 2.0) * (0.75 + 0.25 * minf(t * 6.0, 1.0)))
			var y := stem_h * t
			rings.append([Vector3(crook.x * t * t, y, crook.y * t * t), radius, _tint(stem_colour.darkened(0.15 * (1.0 - t)))])
		_tube(where, rings, around, 0.0)
		# (the top of it under the cap moves with the crook)
		where = where * Transform3D(Basis.IDENTITY, Vector3(crook.x, stem_h, crook.y))
		if ring > 0.0:
			var at := Vector3(crook.x * ring * ring - crook.x, stem_h * ring - stem_h, crook.y * ring * ring - crook.y)
			var rr := stem_radius * lerpf(1.0, stem_taper, ring)
			_skirt(where, at, rr * 1.05, rr * 2.2, rr * 1.6, _tint(stem_colour.lightened(0.1)), around)
	# The cap: its top from the middle to the rim, then its underside back in to the stem
	var profile: Array = PROFILES[cap_shape]
	var cap_rings: Array = []
	for i in profile.size():
		var p: Vector2 = profile[i]
		var t := float(i) / (profile.size() - 1)
		var colour: Color = cap_colour.lerp(rim_colour, smoothstep(0.3, 1.0, t))
		if bands > 0.0 and i % 2 == 1:
			colour = colour.lerp(rim_colour, bands * 0.5)
		cap_rings.append([p.x * r, p.y * h, _tint(colour)])
	var under_y := h * (0.0 if cap_shape != Cap.FUNNEL else -0.6)
	var inner := stem_radius * stem_taper * 1.02 if stem_h > 0.0 and not shelf else 0.0
	var rim: Vector2 = profile[profile.size() - 1]
	var under := _tint(gill_colour)
	if cap_shape == Cap.BALL:
		under = _tint(rim_colour.darkened(0.1))
	cap_rings.append([lerpf(rim.x * r, inner, 0.15), rim.y * h - h * 0.12 if cap_shape != Cap.BALL else 0.0, under])
	cap_rings.append([inner, under_y, under.darkened(0.25)])
	_lathe(where, cap_rings, around + (2 if not shelf else 0), arc, cap_shape == Cap.MOREL)
	if gills and cap_shape != Cap.BALL:
		_gills(where, Vector2(maxf(inner, r * 0.12), under_y), Vector2(rim.x * r * 0.92, rim.y * h - h * 0.1), h * 0.25, under.darkened(0.12), around + 2, arc)
	# Spots and warts on the top
	for k in spots + warts:
		var wart := k >= spots
		var a := _rng.randf_range(arc[0], arc[1])
		var t := _rng.randf_range(0.1, 0.92) if not wart else _rng.randf_range(0.05, 0.85)
		_bump(where, profile, a, t, spot_size * r * _rng.randf_range(0.6, 1.3), wart, _tint(spot_colour))


## Rings up a stem (each [middle, radius, colour]), closed round.
func _tube(where: Transform3D, rings: Array, around: int, glow_amount: float) -> void:
	var points: Array = []
	for one: Array in rings:
		var row: Array = []
		for j in around:
			var a := TAU * j / around
			row.append(where * ((one[0] as Vector3) + Vector3(sin(a), 0.0, cos(a)) * float(one[1])))
		points.append(row)
	for i in rings.size() - 1:
		for j in around:
			var n := (j + 1) % around
			_quad(points[i][j], points[i][n], points[i + 1][n], points[i + 1][j],
					rings[i][2], rings[i][2], rings[i + 1][2], rings[i + 1][2], glow_amount)


## A surface of revolution round the cap's axis, rings [radius, height, colour] from its top's middle out and back in,
## over `arc` (a full turn, or half of one for a shelf). `pitted`: a morel's honeycomb.
func _lathe(where: Transform3D, rings: Array, around: int, arc: Array, pitted: bool) -> void:
	var full: bool = is_equal_approx(float(arc[1]) - float(arc[0]), TAU)
	var columns := around if full else around + 1
	var points: Array = []
	var colours: Array = []
	for i in rings.size():
		var row: Array = []
		var tints: Array = []
		for j in columns:
			var a := lerpf(arc[0], arc[1], float(j) / around)
			var radius: float = rings[i][0]
			var colour: Color = rings[i][2]
			if pitted and i > 0 and i < rings.size() - 3 and (i + j) % 2 == 0:
				radius *= 0.84
				colour = colour.darkened(0.45)
			row.append(where * Vector3(sin(a) * radius, float(rings[i][1]), cos(a) * radius))
			tints.append(colour)
		points.append(row)
		colours.append(tints)
	for i in rings.size() - 1:
		for j in around:
			var n := (j + 1) % columns
			_quad(points[i][j], points[i][n], points[i + 1][n], points[i + 1][j],
					colours[i][j], colours[i][n], colours[i + 1][n], colours[i + 1][j], glow)
	if not full:
		# (a shelf's back, against the wall: closed, so it is not hollow seen from the side)
		var back_a: Array = []
		var back_b: Array = []
		for i in rings.size():
			back_a.append(points[i][0])
			back_b.append(points[i][columns - 1])
		for i in rings.size() - 2:
			_tri(back_a[0], back_a[i + 1], back_a[i + 2], colours[i][0], glow)
			_tri(back_b[0], back_b[i + 2], back_b[i + 1], colours[i][0], glow)


## Gills: thin fins round under the cap from the stem out to the rim, hanging `depth` below its underside; seen from
## both sides.
func _gills(where: Transform3D, from: Vector2, to: Vector2, depth: float, colour: Color, many: int, arc: Array) -> void:
	for j in many:
		var a := lerpf(arc[0], arc[1], (float(j) + 0.5) / many)
		var way := Vector3(sin(a), 0.0, cos(a))
		var p0 := where * (way * from.x + Vector3.UP * from.y)
		var p1 := where * (way * to.x + Vector3.UP * to.y)
		var p2 := where * (way * lerpf(from.x, to.x, 0.45) + Vector3.UP * (lerpf(from.y, to.y, 0.45) - depth))
		_two_sided(p0, p1, p2, colour, glow * 0.4)


## A ring (skirt) round the stem at `at` (from the cap's foot): a flared cone hanging down, seen from both sides.
func _skirt(where: Transform3D, at: Vector3, from_r: float, to_r: float, drop: float, colour: Color, around: int) -> void:
	for j in around:
		var a0 := TAU * j / around
		var a1 := TAU * (j + 1) / around
		var p0 := where * (at + Vector3(sin(a0), 0.0, cos(a0)) * from_r)
		var p1 := where * (at + Vector3(sin(a1), 0.0, cos(a1)) * from_r)
		var q0 := where * (at + Vector3(sin(a0) * to_r, -drop, cos(a0) * to_r))
		var q1 := where * (at + Vector3(sin(a1) * to_r, -drop, cos(a1) * to_r))
		_quad(p0, p1, q1, q0, colour, colour, colour.darkened(0.1), colour.darkened(0.1), 0.0)
		var off := (p1 - p0).cross(q0 - p0).normalized() * 0.0003
		_quad(p0 + off, q0 + off, q1 + off, p1 + off, colour, colour.darkened(0.1), colour.darkened(0.1), colour, 0.0)


## A spot (a low flat patch) or a wart (a little point) on the cap's top at turn `a`, `t` of the way out.
func _bump(where: Transform3D, profile: Array, a: float, t: float, size: float, wart: bool, colour: Color) -> void:
	var span := float(profile.size() - 1)
	var i := mini(int(t * span), profile.size() - 2)
	var f := t * span - i
	var p: Vector2 = (profile[i] as Vector2).lerp(profile[i + 1], f)
	var slope: Vector2 = (profile[i + 1] as Vector2) - (profile[i] as Vector2)
	var way := Vector3(sin(a), 0.0, cos(a))
	var middle := way * p.x * cap_radius + Vector3.UP * p.y * cap_height
	# (the surface's way out there: across its slope)
	var along := (way * slope.x * cap_radius + Vector3.UP * slope.y * cap_height).normalized()
	var side := Vector3(cos(a), 0.0, -sin(a))
	var normal := side.cross(along).normalized()
	if normal.dot(middle - Vector3.UP * cap_height * 0.3) < 0.0:
		normal = -normal
	var corners: Array = []
	var sides := 5
	for k in sides:
		var b := TAU * k / sides + _rng.randf() * 0.4
		corners.append(where * (middle + (side * cos(b) + along * sin(b)) * size + normal * size * 0.05))
	var top := where * (middle + normal * size * (0.9 if wart else 0.3))
	for k in sides:
		_two_sided(top, corners[k], corners[(k + 1) % sides], colour, glow * 0.5)


## A colour as this one mushroom has it (its own hue and shade).
func _tint(c: Color) -> Color:
	return Color.from_hsv(fposmod(c.h + _hue, 1.0), c.s, clampf(c.v * _value, 0.0, 1.0))


func _quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, ca: Color, cb: Color, cc: Color, cd: Color, glow_amount: float) -> void:
	_vertex(a, ca, glow_amount)
	_vertex(b, cb, glow_amount)
	_vertex(c, cc, glow_amount)
	_vertex(a, ca, glow_amount)
	_vertex(c, cc, glow_amount)
	_vertex(d, cd, glow_amount)


func _tri(a: Vector3, b: Vector3, c: Vector3, colour: Color, glow_amount: float) -> void:
	_vertex(a, colour, glow_amount)
	_vertex(b, colour, glow_amount)
	_vertex(c, colour, glow_amount)


func _vertex(at: Vector3, colour: Color, glow_amount: float) -> void:
	_st.set_color(colour)
	_st.set_uv(Vector2(glow_amount, clampf(at.y / _total_height, 0.0, 1.0)))
	_st.add_vertex(at)


## A triangle seen from both sides: its back a hair behind it, so the two do not share points (and so normals).
func _two_sided(a: Vector3, b: Vector3, c: Vector3, colour: Color, glow_amount: float) -> void:
	var off := (b - a).cross(c - a).normalized() * 0.0003
	_tri(a, b, c, colour, glow_amount)
	_tri(a - off, c - off, b - off, colour, glow_amount)
