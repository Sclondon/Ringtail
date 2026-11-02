@tool
class_name FlowerGen
extends Resource
## Any flower, built from code (after TreeGen and MushroomGen; Ringtail, 2026-11-02: "make blackberry bushes and flower
## generator"): a clump of stems, each with a flower at its top of one of three forms: a single HEAD (a daisy, a
## trillium, an iris, a rose: rings of petals round a middle), a SPIKE of florets up the top of the stem (lupine,
## foxglove, fireweed, camas: biggest at the foot of the spike, buds at its tip), or a BALL of florets (a hydrangea).
## Florets may be open petals or hanging BELLS (foxglove, salal). Leaves at the foot (a rosette) and up the stem.
## Low poly (a few dozen to a few hundred triangles a stem), vertex coloured, drawn with PlantLook (cel lit, swaying,
## pushed aside). The same settings and seed always make the same clump.
##
## One:    var g := FlowerGen.preset("Lupine"); g.seed = 3; var mesh := g.mesh()
## Many:   FlowerGen.scatter(parent, transforms, g, 3)   (a MultiMesh per variant, drawn only near)
##
## The mesh's foot is at the origin, up +Y.

enum Form { HEAD, SPIKE, BALL }
enum Petal { ROUND, POINTED, NOTCHED, STRAP, HEART }
enum Leaf { LANCE, BROAD, PALMATE, GRASS, ROUND }

## Each petal shape's width at its foot, middle and tip; each leaf shape's in four steps (few: a petal is 8 triangles).
const PETAL_PROFILES := {
	Petal.ROUND: [0.3, 1.0, 0.45],
	Petal.POINTED: [0.25, 1.0, 0.0],
	Petal.NOTCHED: [0.3, 1.0, 0.7],
	Petal.STRAP: [0.6, 1.0, 0.55],
	Petal.HEART: [0.25, 1.0, 0.85],
}
const LEAF_PROFILES := {
	Leaf.LANCE: [0.2, 1.0, 0.6, 0.0],
	Leaf.BROAD: [0.4, 1.0, 0.75, 0.0],
	Leaf.PALMATE: [0.3, 1.0, 0.45, 0.0],
	Leaf.GRASS: [1.0, 0.9, 0.6, 0.0],
	Leaf.ROUND: [0.5, 1.0, 0.85, 0.25],
}

## Pacific Northwest wildflowers, and a garden's.
const PRESETS := {
	"Lupine": {"form": Form.SPIKE, "count": 3, "spread": 0.08, "stem_height": 0.45, "spike_length": 0.45, "florets": 16,
		"petals": 3, "petal_length": 0.022, "petal_width": 0.03, "petal_shape": Petal.ROUND, "petal_cup": 0.9,
		"petal_colour": Color(0.38, 0.38, 0.85), "tip_colour": Color(0.75, 0.75, 1.0), "centre_size": 0.0,
		"leaf_shape": Leaf.PALMATE, "basal_leaves": 5, "leaf_length": 0.11, "leaf_width": 0.03, "leaflets": 7,
		"leaf_colour": Color(0.25, 0.45, 0.25)},
	"Foxglove": {"form": Form.SPIKE, "count": 2, "spread": 0.06, "stem_height": 0.7, "spike_length": 0.5, "florets": 14,
		"bells": true, "petal_length": 0.05, "petal_width": 0.026, "petal_colour": Color(0.75, 0.35, 0.65),
		"tip_colour": Color(0.92, 0.75, 0.9), "centre_colour": Color(0.95, 0.9, 0.95), "one_sided": 0.7,
		"leaf_shape": Leaf.BROAD, "basal_leaves": 7, "leaf_length": 0.22, "leaf_width": 0.08, "leaf_colour": Color(0.3, 0.42, 0.25)},
	"Fireweed": {"form": Form.SPIKE, "count": 4, "spread": 0.12, "stem_height": 0.75, "spike_length": 0.35, "florets": 12,
		"petals": 4, "petal_length": 0.028, "petal_width": 0.024, "petal_shape": Petal.ROUND, "petal_cup": 0.25,
		"petal_colour": Color(0.85, 0.25, 0.6), "tip_colour": Color(0.95, 0.45, 0.75), "centre_colour": Color(0.95, 0.85, 0.9),
		"centre_size": 0.006, "stem_colour": Color(0.5, 0.25, 0.3), "leaf_shape": Leaf.LANCE, "stem_leaves": 10,
		"leaf_length": 0.1, "leaf_width": 0.018, "leaf_colour": Color(0.28, 0.42, 0.24)},
	"Trillium": {"form": Form.HEAD, "count": 1, "stem_height": 0.18, "petals": 3, "petal_length": 0.06, "petal_width": 0.045,
		"petal_shape": Petal.POINTED, "petal_cup": 0.35, "petal_colour": Color(0.97, 0.96, 0.92), "tip_colour": Color(0.95, 0.85, 0.9),
		"centre_colour": Color(0.95, 0.85, 0.35), "centre_size": 0.01, "face_up": 0.6, "leaf_shape": Leaf.BROAD,
		"whorl_leaves": 3, "leaf_length": 0.1, "leaf_width": 0.09, "leaf_colour": Color(0.22, 0.4, 0.2)},
	"Oxeye daisy": {"form": Form.HEAD, "count": 4, "spread": 0.07, "stem_height": 0.4, "petals": 16, "petal_length": 0.03,
		"petal_width": 0.009, "petal_shape": Petal.NOTCHED, "petal_cup": -0.05, "petal_colour": Color(0.98, 0.98, 0.95),
		"tip_colour": Color(1, 1, 1), "centre_colour": Color(0.95, 0.75, 0.15), "centre_size": 0.013, "face_up": 0.7,
		"leaf_shape": Leaf.LANCE, "basal_leaves": 6, "stem_leaves": 3, "leaf_length": 0.06, "leaf_width": 0.016,
		"leaf_colour": Color(0.28, 0.45, 0.22)},
	"Oregon iris": {"form": Form.HEAD, "count": 3, "spread": 0.06, "stem_height": 0.28, "petals": 3, "petal_length": 0.045,
		"petal_width": 0.03, "petal_shape": Petal.ROUND, "petal_cup": -0.9, "layers": 2, "layer_cup": 1.1,
		"layer_scale": 0.8, "petal_colour": Color(0.45, 0.35, 0.75), "tip_colour": Color(0.6, 0.5, 0.88),
		"centre_colour": Color(0.95, 0.85, 0.4), "centre_size": 0.005, "face_up": 0.9, "leaf_shape": Leaf.GRASS,
		"basal_leaves": 8, "leaf_length": 0.32, "leaf_width": 0.014, "leaf_colour": Color(0.3, 0.45, 0.3)},
	"Columbine": {"form": Form.HEAD, "count": 3, "spread": 0.08, "stem_height": 0.4, "petals": 5, "petal_length": 0.035,
		"petal_width": 0.014, "petal_shape": Petal.POINTED, "petal_cup": 1.1, "layers": 2, "layer_cup": 0.3,
		"layer_scale": 0.65, "petal_colour": Color(0.85, 0.18, 0.15), "tip_colour": Color(0.95, 0.8, 0.25),
		"centre_colour": Color(0.98, 0.85, 0.3), "centre_size": 0.006, "face_up": -0.6, "stem_droop": 0.06,
		"leaf_shape": Leaf.ROUND, "basal_leaves": 6, "leaf_length": 0.05, "leaf_width": 0.04, "leaflets": 3,
		"leaf_colour": Color(0.3, 0.45, 0.32)},
	"Salal blossom": {"form": Form.SPIKE, "count": 3, "spread": 0.12, "stem_height": 0.3, "spike_length": 0.16, "florets": 7,
		"bells": true, "petal_length": 0.02, "petal_width": 0.016, "petal_colour": Color(0.95, 0.88, 0.88),
		"tip_colour": Color(0.9, 0.6, 0.7), "centre_colour": Color(0.9, 0.5, 0.55), "one_sided": 0.9, "stem_droop": 0.12,
		"stem_colour": Color(0.55, 0.3, 0.25), "leaf_shape": Leaf.BROAD, "stem_leaves": 6, "leaf_length": 0.09,
		"leaf_width": 0.06, "leaf_colour": Color(0.18, 0.36, 0.2)},
	"Camas": {"form": Form.SPIKE, "count": 3, "spread": 0.06, "stem_height": 0.4, "spike_length": 0.18, "florets": 7,
		"petals": 6, "petal_length": 0.03, "petal_width": 0.01, "petal_shape": Petal.POINTED, "petal_cup": 0.2,
		"petal_colour": Color(0.35, 0.4, 0.9), "tip_colour": Color(0.5, 0.55, 0.95), "centre_colour": Color(0.95, 0.85, 0.3),
		"centre_size": 0.004, "leaf_shape": Leaf.GRASS, "basal_leaves": 5, "leaf_length": 0.25, "leaf_width": 0.012,
		"leaf_colour": Color(0.32, 0.47, 0.3)},
	"Garden rose": {"form": Form.HEAD, "count": 4, "spread": 0.14, "stem_height": 0.55, "petals": 5, "petal_length": 0.045,
		"petal_width": 0.05, "petal_shape": Petal.HEART, "petal_cup": 1.2, "layers": 4, "layer_cup": -0.2,
		"layer_scale": 0.8, "layer_turn": 0.6, "petal_colour": Color(0.75, 0.1, 0.18), "tip_colour": Color(0.9, 0.25, 0.3),
		"centre_size": 0.0, "face_up": 0.5, "stem_colour": Color(0.25, 0.38, 0.2), "leaf_shape": Leaf.ROUND,
		"stem_leaves": 6, "leaf_length": 0.07, "leaf_width": 0.045, "leaflets": 3, "leaf_colour": Color(0.18, 0.35, 0.18),
		"colour_random": 0.1},
	"Hydrangea": {"form": Form.BALL, "count": 3, "spread": 0.18, "stem_height": 0.5, "florets": 15, "ball_radius": 0.09,
		"petals": 4, "petal_length": 0.022, "petal_width": 0.024, "petal_shape": Petal.ROUND, "petal_cup": 0.15,
		"petal_colour": Color(0.45, 0.55, 0.9), "tip_colour": Color(0.75, 0.6, 0.9), "centre_size": 0.003,
		"centre_colour": Color(0.95, 0.95, 1.0), "stem_leaves": 6, "leaf_shape": Leaf.BROAD, "leaf_length": 0.13,
		"leaf_width": 0.09, "leaf_colour": Color(0.2, 0.4, 0.2), "colour_random": 0.12},
}

@export var seed := 1
@export var form := Form.HEAD
@export_group("Clump")
## How many stems, how far out from the middle (m), how much each one's height varies, how much they lean out.
@export_range(1, 30) var count := 3
@export_range(0.0, 0.6) var spread := 0.08
@export_range(0.0, 0.8) var size_random := 0.25
@export_range(0.0, 0.8) var lean := 0.15
## How much each stem's colours wander.
@export_range(0.0, 0.3) var colour_random := 0.06
@export_group("Stem")
@export_range(0.02, 2.0, 0.01, "or_greater") var stem_height := 0.35
@export_range(0.001, 0.03) var stem_radius := 0.004
## How far its top bends over (m: a nodding flower).
@export_range(0.0, 0.4) var stem_droop := 0.0
@export var stem_colour := Color(0.3, 0.45, 0.22)
@export_group("Flower")
## Petals round each flower, how long and wide (m), their shape, how far they cup up (radians; below 0 they fall back
## like an iris's falls), rings of them (each `layer_scale` the size of the last, cupped `layer_cup` more, turned
## `layer_turn` of a petal's gap).
@export_range(2, 30) var petals := 5
@export_range(0.003, 0.2) var petal_length := 0.03
@export_range(0.002, 0.2) var petal_width := 0.02
@export var petal_shape := Petal.ROUND
@export_range(-1.5, 1.6) var petal_cup := 0.3
@export_range(1, 6) var layers := 1
@export_range(0.3, 1.2) var layer_scale := 0.75
@export_range(-1.5, 1.5) var layer_cup := 0.4
@export_range(0.0, 1.0) var layer_turn := 0.5
@export var petal_colour := Color(0.9, 0.4, 0.6)
@export var tip_colour := Color(1.0, 0.7, 0.8)
## The middle (0: none), its colour.
@export_range(0.0, 0.05) var centre_size := 0.008
@export var centre_colour := Color(0.95, 0.8, 0.2)
## How much a single head faces up (1) rather than out (0), or down (below 0).
@export_range(-1.0, 1.0) var face_up := 0.5
## Florets hang as bells (fused petals: a foxglove's, salal's) instead of open petals.
@export var bells := false
@export_group("Spike and ball")
## A spike: how much of the stem's top it covers, how many florets; how much they face one way (0 all round, 1 one side).
## A ball: its radius.
@export_range(0.02, 1.0) var spike_length := 0.3
@export_range(1, 60) var florets := 12
@export_range(0.0, 1.0) var one_sided := 0.0
@export_range(0.01, 0.4) var ball_radius := 0.08
@export_group("Leaves")
@export var leaf_shape := Leaf.LANCE
## Leaves in a rosette at the foot, up the stem, and in a whorl under a single head (a trillium's three).
@export_range(0, 16) var basal_leaves := 4
@export_range(0, 20) var stem_leaves := 0
@export_range(0, 6) var whorl_leaves := 0
@export_range(0.01, 0.6) var leaf_length := 0.08
@export_range(0.003, 0.3) var leaf_width := 0.025
## Leaflets to a leaf (a lupine's fan of seven, a rose's five, a columbine's three); 1 a simple leaf.
@export_range(1, 9) var leaflets := 1
@export var leaf_colour := Color(0.28, 0.45, 0.22)

var _rng := RandomNumberGenerator.new()
var _m: PlantMesh
var _hue := 0.0
var _value := 1.0

static var _cache := {}


static func names() -> Array:
	return PRESETS.keys()


## A generator set as one of PRESETS (any setting can then be changed).
static func preset(name: String) -> FlowerGen:
	var made := FlowerGen.new()
	var settings: Dictionary = PRESETS.get(name, {})
	for key: String in settings:
		made.set(key, settings[key])
	return made


## The clump's mesh (vertex coloured, one surface, PlantLook's material on it).
func mesh() -> ArrayMesh:
	_rng.seed = seed
	_m = PlantMesh.new(stem_height * (1.0 + size_random) + (ball_radius if form == Form.BALL else 0.0))
	for k in count:
		var out := 0.0 if k == 0 else sqrt(_rng.randf()) * spread
		var round_about := _rng.randf() * TAU
		var foot := Vector3(cos(round_about), 0.0, sin(round_about)) * out
		var high := stem_height * (1.0 + _rng.randf_range(-size_random, size_random))
		var tilt := lean * out / maxf(spread, 0.001) + _rng.randf_range(0.0, 0.08)
		var way := Vector3(cos(round_about), 0.0, sin(round_about)) if out > 0.0 else Vector3(cos(round_about), 0.0, sin(round_about)) * 0.3
		_hue = _rng.randf_range(-colour_random, colour_random) * 0.4
		_value = 1.0 + _rng.randf_range(-colour_random, colour_random)
		_stem(foot, high, way, tilt)
	# The rosette at the foot
	for k in basal_leaves:
		var turn := TAU * k / maxf(basal_leaves, 1) + _rng.randf_range(-0.3, 0.3)
		var out := Vector3(cos(turn), 0.0, sin(turn))
		var rise := 0.9 if leaf_shape == Leaf.GRASS else 0.35
		_leaf(Vector3(0.0, 0.005, 0.0) + out * 0.01, (out + Vector3.UP * rise * _rng.randf_range(0.7, 1.3)).normalized(),
				leaf_length * _rng.randf_range(0.8, 1.15))
	var made := _m.commit()
	_m = null
	return made


## Flowers at `places` (transforms in `parent`'s space: foot, up, size), `variants` meshes of `gen` (seeds gen.seed, +1,
## ...), each one MultiMesh drawn only within `far` m. Returns the MultiMeshInstance3Ds made (children of `parent`).
static func scatter(parent: Node3D, places: Array, gen: FlowerGen, variants := 3, far := 40.0) -> Array[MultiMeshInstance3D]:
	var made: Array[MultiMeshInstance3D] = []
	for v in variants:
		var list: Array = []
		for i in range(v, places.size(), variants):
			list.append(places[i])
		if not list.is_empty():
			made.append(PlantLook.scatter(parent, list, gen.variant(v), far))
	return made


## Its mesh with seed + `offset` (made once, then shared).
func variant(offset: int) -> ArrayMesh:
	var key := "%s|%d" % [var_to_str(_settings()), seed + offset]
	if not _cache.has(key):
		var was := seed
		seed = was + offset
		_cache[key] = mesh()
		seed = was
	return _cache[key]


func _settings() -> Array:
	return [form, count, spread, size_random, lean, colour_random, stem_height, stem_radius, stem_droop, stem_colour,
			petals, petal_length, petal_width, petal_shape, petal_cup, layers, layer_scale, layer_cup, layer_turn,
			petal_colour, tip_colour, centre_size, centre_colour, face_up, bells, spike_length, florets, one_sided,
			ball_radius, leaf_shape, basal_leaves, stem_leaves, whorl_leaves, leaf_length, leaf_width, leaflets, leaf_colour]


func _tint(colour: Color) -> Color:
	var made := colour
	made.h = fposmod(made.h + _hue, 1.0)
	made.v = clampf(made.v * _value, 0.0, 1.0)
	return made


## One stem from `foot`, `high`, leaning out along `way` by `tilt`, its flower(s) at the top.
func _stem(foot: Vector3, high: float, way: Vector3, tilt: float) -> void:
	var points: Array = []
	var radii: Array = []
	var steps := 4
	for s in steps + 1:
		var t := float(s) / steps
		var p := foot + Vector3.UP * high * t + way * sin(tilt) * high * t * t
		p += way * stem_droop * t * t * t * 0.6 - Vector3.UP * stem_droop * t * t * t
		points.append(p)
		radii.append(stem_radius * lerpf(1.0, 0.6, t))
	_m.tube(points, radii, 3, _tint(stem_colour).darkened(0.15), _tint(stem_colour))
	var top: Vector3 = points[steps]
	var axis: Vector3 = (top - (points[steps - 1] as Vector3)).normalized()
	# Leaves up the stem, every other side
	for k in stem_leaves:
		var t := lerpf(0.15, 0.75 if form == Form.HEAD else 0.55, (k + 0.5) / maxf(stem_leaves, 1))
		var at: Vector3 = (points[int(t * steps)] as Vector3).lerp(points[mini(int(t * steps) + 1, steps)], fmod(t * steps, 1.0))
		var turn := k * 2.4 + _rng.randf_range(-0.3, 0.3)
		var out := Vector3(cos(turn), 0.0, sin(turn))
		_leaf(at, (out + Vector3.UP * 0.5).normalized(), leaf_length * lerpf(1.0, 0.6, t) * _rng.randf_range(0.85, 1.1))
	match form:
		Form.HEAD:
			var face := axis.slerp(way.normalized() if way.length() > 0.01 else Vector3.RIGHT, (1.0 - face_up) * 0.5) if face_up >= 0.0 \
					else axis.slerp(Vector3.DOWN, -face_up)
			if face_up < 0.0:
				face = (face + way * 0.4).normalized()
			_floret(top, face.normalized(), 1.0, 1.0)
			for k in whorl_leaves:
				var turn := TAU * k / whorl_leaves + PI / whorl_leaves
				var out := Vector3(cos(turn), 0.0, sin(turn))
				_leaf(top - axis * 0.012, (out + Vector3.DOWN * 0.15).normalized(), leaf_length)
		Form.SPIKE:
			var side := _rng.randf() * TAU
			for f in florets:
				var t := float(f) / maxf(florets - 1, 1)
				var at := top - axis * spike_length * high / maxf(stem_height, 0.01) * (1.0 - t)
				# (round the stem in a spiral, or mostly to one side)
				var turn := lerpf(f * 2.4, side + _rng.randf_range(-0.9, 0.9), one_sided)
				var out := Vector3(cos(turn), 0.0, sin(turn))
				var size := lerpf(1.0, 0.45, t)
				var open := 1.0 if t < 0.75 else lerpf(1.0, 0.0, (t - 0.75) / 0.25)
				var face := (out + axis * (0.35 if not bells else -0.6)).normalized()
				_floret(at + out * stem_radius * 2.0, face, size, open)
		Form.BALL:
			var middle := top + axis * ball_radius * 0.6
			# (a solid heart under the florets, so the head is not a hollow bubble from the side)
			_m.ball(middle, ball_radius * 0.9, _tint(petal_colour).darkened(0.25), 0.9, _rng)
			for f in florets:
				# (spread over the dome, most of a sphere, by a golden spiral)
				var y := 1.0 - 1.6 * (f + 0.5) / florets
				var r := sqrt(maxf(1.0 - y * y, 0.0))
				var turn := f * 2.39996
				var dir := Vector3(cos(turn) * r, y, sin(turn) * r).normalized()
				_floret(middle + dir * ball_radius, dir, _rng.randf_range(0.85, 1.1), 1.0)


## One flower at `at`, facing `face`, `size` of the full one, `open` 0 (a bud) .. 1.
func _floret(at: Vector3, face: Vector3, size: float, open: float) -> void:
	var colour := _tint(petal_colour)
	var tip := _tint(tip_colour)
	if open < 0.3:
		# (a bud: a little closed ball, greener the younger)
		_m.ball(at, petal_length * 0.35 * size, colour.lerp(leaf_colour, 0.5 - open), 1.4, _rng)
		return
	var a := face.cross(Vector3.UP if absf(face.y) < 0.95 else Vector3.RIGHT).normalized()
	var b := face.cross(a).normalized()
	if bells:
		# A bell: a six-sided cone from its foot out along `face`, its mouth flared, darker inside
		var length := petal_length * size
		var mouth := petal_width * 0.5 * size
		var sides := 6
		var foot_ring: Array[Vector3] = []
		var mouth_ring: Array[Vector3] = []
		var lip: Array[Vector3] = []
		for s in sides:
			var t := TAU * s / sides
			var round_dir := a * cos(t) + b * sin(t)
			foot_ring.append(at + round_dir * mouth * 0.35)
			mouth_ring.append(at + face * length + round_dir * mouth)
			lip.append(at + face * length * 1.12 + round_dir * mouth * 1.45)
		var inside := _tint(centre_colour)
		for s in sides:
			var s2 := (s + 1) % sides
			_m.quad(foot_ring[s], foot_ring[s2], mouth_ring[s2], mouth_ring[s], colour, tip)
			_m.quad(mouth_ring[s], mouth_ring[s2], lip[s2], lip[s], tip, tip.lightened(0.1))
			_m.tri(foot_ring[s], at + face * length * 0.3, foot_ring[s2], inside)
		return
	var profile: Array = PETAL_PROFILES[petal_shape]
	for layer in layers:
		var scale := pow(layer_scale, layer) * size * lerpf(0.5, 1.0, open)
		var cup := petal_cup + layer_cup * layer + (1.0 - open) * 0.9
		var shift := layer_turn * layer * TAU / petals
		for p in petals:
			var turn := TAU * p / petals + shift + _rng.randf_range(-0.08, 0.08)
			var out := a * cos(turn) + b * sin(turn)
			var dir := (out * cos(cup) + face * sin(cup)).normalized()
			# (its width round the flower, its face towards where the flower faces)
			var tangent := face.cross(out).normalized()
			_m.blade(at + face * 0.002 * layer, dir, tangent.cross(dir).normalized(), petal_length * scale,
					petal_width * scale, profile, colour.lerp(tip, 0.2 * layer), tip, petal_width * scale * 0.12, 0.0)
	if centre_size > 0.0:
		_m.ball(at + face * centre_size * 0.4, centre_size * size, _tint(centre_colour), 0.6, _rng)


## A leaf (or a fan of leaflets) from `at` along `dir`.
func _leaf(at: Vector3, dir: Vector3, length: float) -> void:
	var profile: Array = LEAF_PROFILES[leaf_shape]
	var colour := _tint(leaf_colour)
	var light := colour.lightened(0.18)
	var side := dir.cross(Vector3.UP if absf(dir.y) < 0.95 else Vector3.RIGHT).normalized()
	# (its face more or less up)
	var facing := side.cross(dir).normalized()
	var droop := length * (0.35 if leaf_shape == Leaf.GRASS else 0.2)
	if leaflets <= 1:
		_m.blade(at, dir, facing, length, leaf_width, profile, colour.darkened(0.1), light, leaf_width * 0.12, droop)
		return
	# A stalk out to the fan, then the leaflets spread from its end
	var stalk_end := at + dir * length * 0.4
	_m.tube([at, stalk_end], [stem_radius * 0.6, stem_radius * 0.4], 3, colour.darkened(0.2), colour)
	var spread_angle := 2.4 if leaf_shape == Leaf.PALMATE else 1.4
	for k in leaflets:
		var t := (float(k) / (leaflets - 1) - 0.5) * spread_angle
		var way := (dir * cos(t) + side * sin(t)).normalized()
		way = (way + Vector3.DOWN * 0.15).normalized()
		var way_side := way.cross(Vector3.UP if absf(way.y) < 0.95 else Vector3.RIGHT).normalized()
		_m.blade(stalk_end, way, way_side.cross(way).normalized(), length * lerpf(1.0, 0.7, absf(t) / maxf(spread_angle, 0.01)),
				leaf_width, profile, colour.darkened(0.1), light, leaf_width * 0.1, droop * 0.4)
