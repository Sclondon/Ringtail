class_name GroveMushrooms
extends Node3D
## Mushrooms out on the hill (the user, 2026-11-02: "we also need a mushroom generator"): GameCommon's MushroomGen
## clusters, a light hand of them (where they grow is Claude's pick): fly agarics, porcini, chanterelles and tiny
## mycena in the grove's wood ring, honey fungus and mycena round the trees' roots, puffballs and porcini out on the
## grass ridges between the four faces, and honey fungus, inkcaps, morels and glowing bonnets under the Shrine face's
## cedars. Only on grass (TownGrass.mask), so never on a road or a path.
##
## Kept in patches of PATCH metres, each a few MultiMeshes drawn only within FAR, and each belonging to its zone
## (Zones): shown only while he is in that zone or one next to it, as ZoneStreaming shows things. The bonnets glow by
## night (DayNight).
##
##   GroveMushrooms.place(world, markers, lawn)

const PATCH := 16.0
const FAR := 40.0
## How much bigger than real ones (he is a raccoon about 0.6 m tall; real ones read as specks).
const SIZE := 2.2
## The kinds that grow in each place, with how often.
const WOOD := {"Fly agaric": 3, "Porcini": 3, "Chanterelle": 3, "Mycena": 2, "Puffball": 1, "Foxfire bonnets": 1}
const ROOTS := {"Honey cluster": 3, "Mycena": 2, "Inkcap": 1}
const RIDGES := {"Puffball": 2, "Porcini": 1, "Mycena": 1}
const SHRINE := {"Honey cluster": 2, "Inkcap": 2, "Morel": 1, "Foxfire bonnets": 2}

var world: World
var _rng := RandomNumberGenerator.new()
var _lawn: TownGrass
var _gens := {}
## Patch cell -> {"zone": int, "kinds": {preset: [Transform3D, ...]}}
var _patches := {}
var _shown := {}
var _look := 0.0


static func place(the_world: World, markers: Dictionary, lawn: TownGrass) -> GroveMushrooms:
	var made := GroveMushrooms.new()
	made.name = "GroveMushrooms"
	made.world = the_world
	made._lawn = lawn
	made._rng.seed = 23
	the_world.add_child(made)
	if not markers.has("grove_heart"):
		return made
	var heart: Vector3 = (markers["grove_heart"] as Transform3D).origin
	# The wood ring round the clearing
	for _k in 100:
		var a := made._rng.randf() * TAU
		made._grow(heart + Vector3(cos(a), 0.0, sin(a)) * made._rng.randf_range(21.0, 31.0), WOOD)
	# Round the trees' roots (the grove's, and the Shrine face's cedars more thickly)
	var shrine := -1
	if the_world.zones:
		shrine = the_world.zones.names.find("Shrine")
	for name: String in markers:
		if not (name.begins_with("treep_") or name.begins_with("tree_")):
			continue
		var at: Vector3 = (markers[name] as Transform3D).origin
		var in_shrine := shrine >= 0 and the_world.zones.zone_of(at) == shrine
		var in_grove := Vector2(at.x - heart.x, at.z - heart.z).length() < 34.0
		if not (in_shrine or in_grove) or made._rng.randf() > (0.8 if in_shrine else 0.45):
			continue
		for _k in made._rng.randi_range(1, 2):
			var a := made._rng.randf() * TAU
			made._grow(at + Vector3(cos(a), 0.0, sin(a)) * made._rng.randf_range(0.9, 1.8), SHRINE if in_shrine else ROOTS, 0.8)
	# Out on the grass ridges where the faces meet (the diagonals between the four streets)
	for ridge in 4:
		var a := TAU * (ridge + 0.5) / 4.0
		for _k in 9:
			var along := made._rng.randf_range(62.0, 150.0)
			var b := a + made._rng.randf_range(-0.05, 0.05)
			made._grow(heart + Vector3(cos(b), 0.0, sin(b)) * along, RIDGES)
	made._build()
	return made


## A cluster at `near` (x, z; any height), or as near it as there is grass (within `jitter` m), of a kind from `kinds`.
func _grow(near: Vector3, kinds: Dictionary, jitter := 2.5) -> void:
	if _lawn == null:
		return
	var p := Vector2(near.x, near.z)
	var tries := 0
	while _lawn.mask(p) < 0.5:
		tries += 1
		if tries > 8:
			return
		p = Vector2(near.x, near.z) + Vector2.from_angle(_rng.randf() * TAU) * _rng.randf() * jitter
	var at := Vector3(p.x, _lawn.height(p), p.y)
	var total := 0
	for kind: String in kinds:
		total += int(kinds[kind])
	var pick := _rng.randi() % total
	var chosen: String = kinds.keys()[0]
	for kind: String in kinds:
		pick -= int(kinds[kind])
		if pick < 0:
			chosen = kind
			break
	var cell := Vector2i((p / PATCH).floor())
	if not _patches.has(cell):
		_patches[cell] = {"zone": world.zones.zone_of(at) if world.zones else -1, "kinds": {}}
	var lists: Dictionary = _patches[cell]["kinds"]
	if not lists.has(chosen):
		lists[chosen] = []
	var size := SIZE * _rng.randf_range(0.75, 1.25)
	(lists[chosen] as Array).append(Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3.ONE * size), at))


func _build() -> void:
	for cell: Vector2i in _patches:
		var patch := Node3D.new()
		patch.name = "Patch_%d_%d" % [cell.x, cell.y]
		var middle := (Vector2(cell) + Vector2(0.5, 0.5)) * PATCH
		var lists: Dictionary = _patches[cell]["kinds"]
		var low := 0.0
		for kind: String in lists:
			for where: Transform3D in lists[kind]:
				low += where.origin.y
		var count := 0
		for kind: String in lists:
			count += (lists[kind] as Array).size()
		patch.position = Vector3(middle.x, low / maxf(count, 1), middle.y)
		add_child(patch)
		for kind: String in lists:
			if not _gens.has(kind):
				_gens[kind] = MushroomGen.preset(kind)
			var places: Array = []
			for where: Transform3D in lists[kind]:
				places.append(Transform3D(where.basis, where.origin - patch.position))
			MushroomGen.scatter(patch, places, _gens[kind], mini(places.size(), 2), FAR, Settings.low_poly)
		_shown[cell] = patch


## How many clusters (for a test).
func count() -> int:
	var total := 0
	for cell: Vector2i in _patches:
		for kind: String in _patches[cell]["kinds"]:
			total += (_patches[cell]["kinds"][kind] as Array).size()
	return total


func _process(delta: float) -> void:
	# (looked up by name: the day and night is another part of the game, there or not)
	var cycle := world.get_node_or_null(^"DayNight")
	if cycle:
		MushroomLook.set_night(float(cycle.get(&"night")))
	_look -= delta
	if _look > 0.0 or world.zones == null or world.zones.current < 0 or world.get_node_or_null(^"ZoneStreaming") == null:
		return
	_look = 0.5
	var here: int = world.zones.current
	var grove: int = world.zones.grove
	var sides := grove
	for cell: Vector2i in _shown:
		var zone: int = _patches[cell]["zone"]
		var near := zone < 0 or zone == here or zone == grove or here == grove \
				or absi(zone - here) == 1 or absi(zone - here) == sides - 1
		(_shown[cell] as Node3D).visible = near
