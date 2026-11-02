@tool
class_name BrambleGen
extends Resource
## A blackberry bramble, built from code (Ringtail, 2026-11-02: "make blackberry bushes"; a Himalayan blackberry, the
## Pacific Northwest's): a mound of thorny canes rising steeply from its middle and arching over to root again at its
## edge, leaves of three to five serrated leaflets along them, clusters of white-pink flowers, and berries from green
## through red to black. A dark heart of tangle inside so the mound reads as a thicket, not a cage of sticks. Low
## poly (about two to three thousand triangles a mound), vertex coloured, drawn with PlantLook. The same settings and
## seed always make the same mound.
##
## One:    var g := BrambleGen.preset("Thicket"); g.seed = 2; var mesh := g.mesh()
## Many:   BrambleGen.scatter(parent, transforms, g, 3)
##
## The mesh's foot is at the origin, up +Y; it spreads about `radius` round.

const PRESETS := {
	"Mound": {},
	"Thicket": {"radius": 2.2, "height": 1.7, "canes": 16, "leaves_per_metre": 3.2},
	"Low tangle": {"radius": 1.4, "height": 0.7, "canes": 10, "arch": 0.35},
	"In flower": {"flowers": 0.8, "berries": 0.1},
	"Ripe": {"flowers": 0.1, "berries": 0.9, "ripeness": 0.85},
	"Green": {"flowers": 0.3, "berries": 0.5, "ripeness": 0.1},
}

@export var seed := 1
@export_group("Mound")
## How far it spreads (m) and how high it stands at its middle; how many canes; how high (0..1 of `height`) a cane's
## arch peaks before it comes down (lower: a sprawling tangle).
@export_range(0.3, 6.0, 0.01, "or_greater") var radius := 1.7
@export_range(0.2, 4.0, 0.01, "or_greater") var height := 1.3
@export_range(3, 40) var canes := 12
@export_range(0.1, 1.0) var arch := 0.7
@export_range(0.004, 0.05) var cane_radius := 0.014
## Thorns along the canes (each metre).
@export_range(0.0, 20.0) var thorns_per_metre := 7.0
@export var cane_colour := Color(0.42, 0.2, 0.22)
@export var young_colour := Color(0.38, 0.5, 0.25)
@export_group("Leaves")
@export_range(0.0, 8.0) var leaves_per_metre := 2.6
## Leaflets to a leaf (3 or 5), how long and wide (m).
@export_range(1, 7) var leaflets := 3
@export_range(0.03, 0.3) var leaf_length := 0.12
@export_range(0.02, 0.2) var leaf_width := 0.07
@export var leaf_colour := Color(0.17, 0.33, 0.15)
@export var leaf_under := Color(0.42, 0.5, 0.36)
@export_group("Flowers and berries")
## How many of the canes' tips and side shoots carry a cluster of flowers, or of berries (0..1); how ripe the berries are
## on the whole (0 green and red, 1 mostly black).
@export_range(0.0, 1.0) var flowers := 0.35
@export_range(0.0, 1.0) var berries := 0.5
@export_range(0.0, 1.0) var ripeness := 0.55
@export var petal_colour := Color(0.97, 0.88, 0.9)
@export var berry_ripe := Color(0.1, 0.05, 0.12)
@export var berry_red := Color(0.7, 0.1, 0.12)
@export var berry_green := Color(0.55, 0.65, 0.3)

var _rng := RandomNumberGenerator.new()
var _m: PlantMesh
var _cards: SurfaceTool

static var _cache := {}


static func names() -> Array:
	return PRESETS.keys()


static func preset(name: String) -> BrambleGen:
	var made := BrambleGen.new()
	var settings: Dictionary = PRESETS.get(name, {})
	for key: String in settings:
		made.set(key, settings[key])
	return made


## The mound's mesh (vertex coloured, one surface, PlantLook's material on it).
func mesh() -> ArrayMesh:
	_rng.seed = seed
	_m = PlantMesh.new(height * 1.1)
	_cards = SurfaceTool.new()
	_cards.begin(Mesh.PRIMITIVE_TRIANGLES)
	_heart()
	for k in canes:
		_cane(k)
	var made := _m.commit()
	# (the leaves: a second surface of cards drawn by Warren's bush shader, Undergrowth's, sprays of leaves cut out)
	_cards.index()
	_cards.commit(made)
	made.surface_set_material(made.get_surface_count() - 1, Undergrowth.shared_material(Undergrowth.Kind.BUSH))
	_m = null
	_cards = null
	return made


static func scatter(parent: Node3D, places: Array, gen: BrambleGen, variants := 3, far := 55.0, shadows := true) -> Array[MultiMeshInstance3D]:
	var made: Array[MultiMeshInstance3D] = []
	for v in variants:
		var list: Array = []
		for i in range(v, places.size(), variants):
			list.append(places[i])
		if not list.is_empty():
			made.append(PlantLook.scatter(parent, list, gen.variant(v), far, shadows, true))
	return made


func variant(offset: int) -> ArrayMesh:
	var key := "%s|%d" % [var_to_str(_settings()), seed + offset]
	if not _cache.has(key):
		var was := seed
		seed = was + offset
		_cache[key] = mesh()
		seed = was
	return _cache[key]


func _settings() -> Array:
	return [radius, height, canes, arch, cane_radius, thorns_per_metre, cane_colour, young_colour, leaves_per_metre,
			leaflets, leaf_length, leaf_width, leaf_colour, leaf_under, flowers, berries, ripeness, petal_colour,
			berry_ripe, berry_red, berry_green]


## The thicket's mass: lumps of leaf sprays (cards drawn by Undergrowth's bush shader) heaped into a mound, darker deep
## inside and low down, so it reads as a dense tangle and not a cage of sticks.
func _heart() -> void:
	var lumps: Array[Vector4] = [Vector4(0.0, height * 0.42, 0.0, minf(radius * 0.5, height * 0.55))]
	var ring := maxi(4, int(radius * 3.0))
	for l in ring:
		var turn := TAU * l / ring + _rng.randf_range(-0.3, 0.3)
		var out := radius * _rng.randf_range(0.4, 0.62)
		var size := radius * _rng.randf_range(0.26, 0.36)
		lumps.append(Vector4(cos(turn) * out, size * 0.75, sin(turn) * out, size))
	for lump in lumps:
		var middle := Vector3(lump.x, lump.y, lump.z)
		for c in int(lump.w * lump.w * 95.0 * leaves_per_metre / 2.6):
			var dir := Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-0.4, 1), _rng.randf_range(-1, 1)).normalized()
			var deep := _rng.randf_range(0.6, 1.05) if _rng.randf() < 0.8 else _rng.randf_range(0.2, 0.6)
			var at := middle + dir * lump.w * deep * Vector3(1.0, 0.85, 1.0)
			at.y = maxf(at.y, _rng.randf_range(0.04, 0.14))
			_card(at, dir, clampf(deep * 0.55 + at.y / maxf(height, 0.1) * 0.45, 0.0, 1.0))


## A card of leaves at `at`, facing about `out`, lit `light` (0 deep inside .. 1 at the top outside).
func _card(at: Vector3, out: Vector3, light: float, size := 1.0) -> void:
	var facing := (out + Vector3(_rng.randf_range(-0.5, 0.5), _rng.randf_range(-0.3, 0.5), _rng.randf_range(-0.5, 0.5))).normalized()
	var a := facing.cross(Vector3.UP if absf(facing.y) < 0.95 else Vector3.RIGHT).normalized()
	var b := facing.cross(a).normalized()
	var roll := _rng.randf() * TAU
	var s := _rng.randf_range(0.2, 0.3) * size * leaf_length / 0.12
	var u := (a * cos(roll) + b * sin(roll)) * s
	var v := (b * cos(roll) - a * sin(roll)) * s
	var shade := leaf_colour.darkened(0.5).lerp(leaf_colour.lightened(0.12), light * _rng.randf_range(0.75, 1.0))
	Undergrowth._card(_cards, [at - u - v, at + u - v, at + u + v, at - u + v], [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1),
			Vector2(0, 1)], _rng.randf(), light, shade, (out + Vector3.UP * 0.35).normalized())


## One cane: up from near the middle, arching over and down to root near the edge.
func _cane(index: int) -> void:
	var turn := TAU * index / canes + _rng.randf_range(-0.35, 0.35)
	var out := Vector3(cos(turn), 0.0, sin(turn))
	var foot := out * _rng.randf_range(0.0, radius * 0.3)
	var reach := radius * _rng.randf_range(0.65, 1.1)
	var peak := height * _rng.randf_range(0.75, 1.15) * (1.0 if index % 3 else arch + (1.0 - arch) * 0.4)
	var bend := out * reach * arch * 0.45 + Vector3.UP * peak * 1.35
	var land := out * reach + Vector3.DOWN * 0.05
	var steps := 7
	var points: Array = []
	var radii: Array = []
	for s in steps + 1:
		var t := float(s) / steps
		var p := foot.lerp(bend, t).lerp(bend.lerp(land, t), t)
		p += out.cross(Vector3.UP) * sin(t * PI) * _rng.randf_range(-0.12, 0.12)
		points.append(p)
		radii.append(cane_radius * lerpf(1.0, 0.45, t))
	var young := _rng.randf() < 0.35
	_m.tube(points, radii, 4, cane_colour.darkened(0.2), young_colour if young else cane_colour)
	var length := 0.0
	for s in steps:
		length += (points[s] as Vector3).distance_to(points[s + 1])
	# Thorns: little hooked points along it, bent back towards its foot
	for k in int(length * thorns_per_metre):
		var t := _rng.randf_range(0.05, 0.95)
		var at := _along(points, t)
		var dir := (_along(points, minf(t + 0.02, 1.0)) - at).normalized()
		var side := dir.cross(Vector3.UP if absf(dir.y) < 0.95 else Vector3.RIGHT).normalized().rotated(dir, _rng.randf() * TAU)
		var base := at + side * cane_radius * 0.8
		_m.tri(base - dir * 0.008, base + dir * 0.008, base + side * 0.02 - dir * 0.012, cane_colour.lightened(0.15))
	# Leaves along it where it arches out of the mound: sprays (cards), and a real leaf now and then
	for k in int(length * leaves_per_metre * 1.6):
		var t := lerpf(0.3, 1.0, _rng.randf())
		var at := _along(points, t)
		var dir := (_along(points, minf(t + 0.02, 1.0)) - at).normalized()
		var side := dir.cross(Vector3.UP).normalized() * (1.0 if k % 2 == 0 else -1.0)
		var off := (side + Vector3.UP * 0.4).normalized()
		_card(at + off * 0.08, off, clampf(at.y / maxf(height, 0.1), 0.3, 1.0), 0.8)
		if k % 7 == 0:
			_leaf(at, (side + Vector3.UP * 0.35 + dir * 0.2).normalized())
	# Its tip and a side shoot or two: flowers or berries
	# (held out past its leaves, so they show on the mound's outside)
	for shoot in [0.78, 0.62, 0.46, 0.34]:
		var roll := _rng.randf()
		var at := _along(points, shoot + _rng.randf_range(-0.05, 0.05))
		var away := (Vector3(at.x, 0.0, at.z).normalized() * 0.7 + Vector3.UP * 0.5).normalized() * 0.16
		if roll < flowers:
			_flowers(at + away)
		elif roll < flowers + berries:
			_berries(at + away)


## The point `t` of the way along a line of points.
func _along(points: Array, t: float) -> Vector3:
	var f := clampf(t, 0.0, 1.0) * (points.size() - 1)
	var k := mini(int(f), points.size() - 2)
	return (points[k] as Vector3).lerp(points[k + 1], f - k)


## A leaf of `leaflets` serrated leaflets (the middle one longest) on a short stalk, from `at` out along `dir`.
func _leaf(at: Vector3, dir: Vector3) -> void:
	var size := _rng.randf_range(0.8, 1.2)
	var stalk := at + dir * leaf_length * 0.35 * size
	_m.tri(at, stalk, at + Vector3.UP * 0.006, young_colour.darkened(0.2))
	var side := dir.cross(Vector3.UP if absf(dir.y) < 0.95 else Vector3.RIGHT).normalized()
	var colour := leaf_colour.lerp(leaf_colour.lightened(0.15), _rng.randf())
	var profile := [0.3, 1.0, 0.7, 0.0]
	for k in leaflets:
		var t := 0.0 if leaflets == 1 else (float(k) / (leaflets - 1) - 0.5) * 2.0
		var way := (dir * cos(t * 0.9) + side * sin(t * 0.9) + Vector3.DOWN * 0.2).normalized()
		var way_side := way.cross(Vector3.UP if absf(way.y) < 0.95 else Vector3.RIGHT).normalized()
		var long := leaf_length * size * (1.0 - 0.3 * absf(t))
		_m.blade(stalk, way, way_side.cross(way).normalized(), long, leaf_width * size * (1.0 - 0.2 * absf(t)), profile,
				colour.darkened(0.15), colour.lerp(leaf_under, 0.15), leaf_width * 0.12, long * 0.25, 2)


## A cluster of five-petalled flowers.
func _flowers(at: Vector3) -> void:
	for f in _rng.randi_range(2, 4):
		var p := at + Vector3(_rng.randf_range(-0.05, 0.05), _rng.randf_range(0.0, 0.05), _rng.randf_range(-0.05, 0.05))
		var face := (Vector3.UP + Vector3(_rng.randf_range(-0.6, 0.6), 0.0, _rng.randf_range(-0.6, 0.6))).normalized()
		var a := face.cross(Vector3.RIGHT if absf(face.x) < 0.9 else Vector3.FORWARD).normalized()
		var b := face.cross(a).normalized()
		for k in 5:
			var turn := TAU * k / 5.0
			var out := (a * cos(turn) + b * sin(turn)).normalized()
			var dir := (out + face * 0.25).normalized()
			var tangent := face.cross(out).normalized()
			_m.blade(p, dir, tangent.cross(dir).normalized(), 0.03, 0.026, [0.3, 1.0, 0.6], petal_colour.darkened(0.05),
					petal_colour.lerp(Color(0.95, 0.6, 0.75), 0.4))
		_m.ball(p + face * 0.004, 0.006, Color(0.9, 0.85, 0.5), 0.6, _rng)


## A cluster of berries, each a lumpy ball, green, red or black by how ripe.
func _berries(at: Vector3) -> void:
	for f in _rng.randi_range(3, 5):
		var p := at + Vector3(_rng.randf_range(-0.05, 0.05), _rng.randf_range(-0.04, 0.03), _rng.randf_range(-0.05, 0.05))
		var ripe := clampf(ripeness + _rng.randf_range(-0.45, 0.45), 0.0, 1.0)
		var colour := berry_green.lerp(berry_red, smoothstep(0.0, 0.45, ripe)).lerp(berry_ripe, smoothstep(0.45, 0.85, ripe))
		# (two lumpy balls one in the other: rounder, a little drupelet-bumpy)
		_m.ball(p, 0.02, colour, 1.15, _rng)
		_m.ball(p + Vector3(0.003, 0.002, -0.003), 0.019, colour.lightened(0.08), 1.0, _rng)
