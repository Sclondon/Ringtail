class_name GrovePlants
extends Node3D
## The hill's plants (the user, 2026-11-02: "we should bring in the ferns from warren", "and make blackberry bushes and
## flower generator"; the game is set in the Pacific Northwest): GameCommon's undergrowth, which is Warren's ferns,
## bushes and moss (Undergrowth) and the new BrambleGen and FlowerGen. Where they grow is Claude's pick:
##
##   ferns, moss and salal-like bushes   thick under the grove's trees and through its woods; a few under trees elsewhere
##   blackberry brambles                 at the edge of the grove's woods, on the banks beside the roads, and over the
##                                       building site's empty lots (Construction)
##   wildflowers                         in drifts on the grove's lawns, trilliums under its trees, on the verges along
##                                       the roads; roses, hydrangeas and foxgloves in the front gardens of the suburb
##                                       (Rural)
##
## Only on grass (TownGrass.mask), so never on a road or a path; read from the world's markers (tree_, treep_, road_)
## and the zones, so it follows the town however it is laid out. Kept in patches of PATCH metres, each drawn only near
## (FAR_*), and shown only while he is in its zone or one next to it, as ZoneStreaming shows things. In a bramble
## thicket he is hidden, as in tall grass (`in_thicket`, from Hazards.hidden: Claude's pick).
## (Left out with RINGTAIL_NO_PLANTS set, to measure against: tests/perf_zones.gd.)
##
##   GrovePlants.place(world, markers, lawn)

const PATCH := 24.0
const FAR_FERNS := 38.0
const FAR_FLOWERS := 38.0
const FAR_BRAMBLES := 60.0
## How much bigger than real the flowers are drawn (he is a raccoon about half a metre tall; real ones read as specks).
const FLOWER_SIZE := 1.4
const MEADOW := {"Oxeye daisy": 4, "Lupine": 3, "Camas": 2, "Columbine": 1, "Fireweed": 1}
const VERGE := {"Fireweed": 3, "Oxeye daisy": 3, "Lupine": 2, "Foxglove": 1}
const GARDEN := {"Garden rose": 3, "Hydrangea": 3, "Foxglove": 2, "Lupine": 1}
const SHADE := {"Trillium": 3, "Salal blossom": 2, "Foxglove": 1, "Columbine": 1}
const BRAMBLES := {"Mound": 3, "Thicket": 1, "In flower": 2, "Ripe": 2, "Green": 1, "Low tangle": 2}

var world: World
var _rng := RandomNumberGenerator.new()
var _lawn: TownGrass
var _heart := Vector3.ZERO
var _industrial := -1
var _flower_gens := {}
var _bramble_gens := {}
## Patch cell -> {"zone": int, "flowers": {preset: [Transform3D]}, "brambles": {preset: [Transform3D]}, "under": [[kind, Transform3D]]}
var _patches := {}
var _shown := {}
var _look := 0.0
## The thickets he hides in: (x, z, radius).
static var _thickets: Array[Vector3] = []
static var current: GrovePlants


static func place(the_world: World, markers: Dictionary, lawn: TownGrass) -> GrovePlants:
	var made := GrovePlants.new()
	made.name = "GrovePlants"
	made.world = the_world
	made._lawn = lawn
	made._rng.seed = 47
	current = made
	_thickets.clear()
	the_world.add_child(made)
	if lawn == null or not markers.has("grove_heart") or OS.get_environment("RINGTAIL_NO_PLANTS") != "":
		return made
	made._heart = (markers["grove_heart"] as Transform3D).origin
	made._set_out(markers)
	made._build()
	return made


## Whether `at` is down in a bramble thicket (for Hazards.hidden).
static func in_thicket(at: Vector3) -> bool:
	if current == null or not is_instance_valid(current) or current._lawn == null:
		return false
	var p := Vector2(at.x, at.z)
	if absf(at.y - current._lawn.height(p)) > 0.5:
		return false
	for thicket in _thickets:
		if Vector2(thicket.x, thicket.y).distance_to(p) < thicket.z:
			return true
	return false


func _set_out(markers: Dictionary) -> void:
	var grove_radius := Zones.GROVE_RADIUS
	var zones := world.zones
	var grove := zones.grove if zones else -1
	var rural := _zone_named(["rural", "suburb"])
	var building_site := _zone_named(["construction", "building"])
	# (brambles thicker on the waste ground by the works and the sewers)
	_industrial = _zone_named(["industrial", "factory", "works"])
	# Under the trees: ferns, moss and bushes, thick in the grove; trilliums and salal in their shade
	var grove_trees: Array[Vector3] = []
	for name: String in markers:
		if not (name.begins_with("tree_") or name.begins_with("treep_") or name == "great_oak"):
			continue
		var at: Vector3 = (markers[name] as Transform3D).origin
		var in_grove := zones != null and zones.zone_of(at) == grove
		if in_grove:
			grove_trees.append(at)
		if not in_grove and _rng.randf() > 0.35:
			continue
		for _k in (_rng.randi_range(3, 6) if in_grove else _rng.randi_range(1, 2)):
			_under(at, _rng.randf_range(1.2, 4.0), Undergrowth.Kind.FERN)
		if _rng.randf() < 0.5:
			_under(at, _rng.randf_range(0.8, 2.5), Undergrowth.Kind.MOSS)
		if in_grove and _rng.randf() < 0.35:
			_under(at, _rng.randf_range(2.5, 4.5), Undergrowth.Kind.BUSH)
		if in_grove and _rng.randf() < 0.6:
			_flowers(at, _rng.randf_range(1.5, 4.0), SHADE, _rng.randi_range(1, 3), 1.2)
	# Through the grove's woods (its outer part): ferns in drifts
	for _k in 70:
		var a := _rng.randf() * TAU
		var spot := _heart + Vector3(cos(a), 0.0, sin(a)) * _rng.randf_range(grove_radius * 0.5, grove_radius * 0.95)
		for _j in _rng.randi_range(2, 4):
			_under(spot, _rng.randf_range(0.0, 2.5), Undergrowth.Kind.FERN)
	# On the grove's lawns: drifts of wildflowers, a kind to a drift
	for _k in 26:
		var a := _rng.randf() * TAU
		var spot := _heart + Vector3(cos(a), 0.0, sin(a)) * _rng.randf_range(5.0, grove_radius * 0.55)
		_flowers(spot, 0.0, MEADOW, _rng.randi_range(3, 6), 2.5)
	# At the woods' edge: brambles just outside the outermost trees
	grove_trees.sort_custom(func(a: Vector3, b: Vector3) -> bool: return _flat(a - _heart) > _flat(b - _heart))
	for k in mini(grove_trees.size(), 40):
		if _rng.randf() < 0.6:
			var out := Vector3(grove_trees[k].x - _heart.x, 0.0, grove_trees[k].z - _heart.z).normalized()
			_bramble(grove_trees[k] + out * _rng.randf_range(2.5, 4.5) + out.cross(Vector3.UP) * _rng.randf_range(-2.0, 2.0))
	# Along the roads: brambles on the banks, flowers on the verges, gardens in the suburb
	var loop := 0
	while markers.has("road_%d_0" % loop):
		var points: Array[Vector3] = []
		var k := 0
		while markers.has("road_%d_%d" % [loop, k]):
			points.append((markers["road_%d_%d" % [loop, k]] as Transform3D).origin)
			k += 1
		_along_road(points, rural)
		loop += 1
	# The building site's empty lots: brambles taking over
	if building_site >= 0 and zones:
		var middle: Vector3 = zones.middles[building_site]
		for _k in 30:
			var spot := middle + Vector3(_rng.randf_range(-45.0, 45.0), 0.0, _rng.randf_range(-45.0, 45.0))
			if zones.zone_of(spot) == building_site:
				_bramble(spot)


## The zone whose name has one of `words` in it, or -1.
func _zone_named(words: Array) -> int:
	if world.zones == null:
		return -1
	for k in world.zones.names.size():
		for word: String in words:
			if world.zones.names[k].to_lower().contains(word):
				return k
	return -1


func _flat(v: Vector3) -> float:
	return Vector2(v.x, v.z).length()


## Along a road loop's centre line: out from it each side to the first grass (past the road and its pavement), then a
## bank of brambles, a verge of flowers, or (in the suburb) a front garden.
func _along_road(points: Array[Vector3], rural: int) -> void:
	# (every 9 m or so along it, however finely its points are set)
	var next := _rng.randf_range(0.0, 9.0)
	var gone := 0.0
	for k in points.size():
		var a := points[k]
		var b := points[(k + 1) % points.size()]
		var length := _flat(b - a)
		while next < gone + length:
			var at := a.lerp(b, (next - gone) / maxf(length, 0.001))
			next += _rng.randf_range(6.0, 12.0)
			var along := Vector3(b.x - a.x, 0.0, b.z - a.z).normalized()
			var side := along.cross(Vector3.UP) * (1.0 if _rng.randf() < 0.5 else -1.0)
			var edge := Vector3.INF
			for step in range(12, 40):
				var p := at + side * step * 0.5
				if _lawn.mask(Vector2(p.x, p.z)) >= 0.5:
					edge = p
					break
			if edge == Vector3.INF:
				continue
			var zone := world.zones.zone_of(edge) if world.zones else -1
			var roll := _rng.randf()
			if zone == rural and rural >= 0:
				if roll < 0.55:
					_flowers(edge + side * _rng.randf_range(1.5, 4.0), 0.0, GARDEN, _rng.randi_range(2, 4), 1.5)
			elif roll < (0.3 if zone == _industrial else 0.18):
				_bramble(edge + side * _rng.randf_range(2.2, 3.5))
			elif roll < 0.45:
				_flowers(edge + side * _rng.randf_range(0.4, 1.5), 0.0, VERGE, _rng.randi_range(2, 4), 2.0)
		gone += length


## The patch a spot is in (made when first wanted).
func _patch(at: Vector3) -> Dictionary:
	var cell := Vector2i((Vector2(at.x, at.z) / PATCH).floor())
	if not _patches.has(cell):
		_patches[cell] = {"zone": world.zones.zone_of(at) if world.zones else -1, "flowers": {}, "brambles": {}, "under": []}
	return _patches[cell]


## The nearest grass to `near` (within `jitter` m, a few tries), on the ground; Vector3.INF if none.
func _ground(near: Vector3, jitter := 1.5) -> Vector3:
	var p := Vector2(near.x, near.z)
	var tries := 0
	while _lawn.mask(p) < 0.5:
		tries += 1
		if tries > 6:
			return Vector3.INF
		p = Vector2(near.x, near.z) + Vector2.from_angle(_rng.randf() * TAU) * _rng.randf() * jitter
	return Vector3(p.x, _lawn.height(p), p.y)


func _pick(kinds: Dictionary) -> String:
	var total := 0
	for kind: String in kinds:
		total += int(kinds[kind])
	var pick := _rng.randi() % total
	for kind: String in kinds:
		pick -= int(kinds[kind])
		if pick < 0:
			return kind
	return kinds.keys()[0]


## One of Warren's low plants `out` m from `from`, at a random way round.
func _under(from: Vector3, out: float, kind: Undergrowth.Kind) -> void:
	var a := _rng.randf() * TAU
	var at := _ground(from + Vector3(cos(a), 0.0, sin(a)) * out)
	if at == Vector3.INF:
		return
	var size := _rng.randf_range(0.7, 1.15) if kind == Undergrowth.Kind.FERN else _rng.randf_range(0.6, 1.0)
	(_patch(at)["under"] as Array).append([kind, Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3.ONE * size), at)])


## A drift of `clumps` clumps of one kind from `kinds`, round a spot `out` m from `from`, spread over `spread` m.
func _flowers(from: Vector3, out: float, kinds: Dictionary, clumps: int, spread: float) -> void:
	var a := _rng.randf() * TAU
	var middle := from + Vector3(cos(a), 0.0, sin(a)) * out
	var kind := _pick(kinds)
	for _k in clumps:
		var at := _ground(middle + Vector3(_rng.randf_range(-spread, spread), 0.0, _rng.randf_range(-spread, spread)))
		if at == Vector3.INF or not _clear(at, 0.3):
			continue
		var lists: Dictionary = _patch(at)["flowers"]
		if not lists.has(kind):
			lists[kind] = []
		var size := FLOWER_SIZE * _rng.randf_range(0.8, 1.2)
		(lists[kind] as Array).append(Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3.ONE * size), at))


## Whether the ground round `at` out to `reach` is all grass at about its height (no wall's edge, road or drop
## under a bramble's spread).
func _clear(at: Vector3, reach: float) -> bool:
	for k in 8:
		for out: float in [reach * 0.5, reach]:
			var p := Vector2(at.x, at.z) + Vector2.from_angle(TAU * k / 8.0) * out
			if _lawn.mask(p) < 0.5 or absf(_lawn.height(p) - at.y) > maxf(0.4, out * 0.6):
				return false
	return true


## A bramble mound at `near` (the nearest grass), a thicket to hide in.
func _bramble(near: Vector3) -> void:
	var kind := _pick(BRAMBLES)
	if not _bramble_gens.has(kind):
		_bramble_gens[kind] = BrambleGen.preset(kind)
	var reach: float = (_bramble_gens[kind] as BrambleGen).radius * 0.8
	var at := Vector3.INF
	for _try in 5:
		var spot := _ground(near + Vector3(_rng.randf_range(-2.0, 2.0), 0.0, _rng.randf_range(-2.0, 2.0)), 2.5)
		if spot != Vector3.INF and _clear(spot, reach):
			at = spot
			break
	if at == Vector3.INF:
		return
	var lists: Dictionary = _patch(at)["brambles"]
	if not lists.has(kind):
		lists[kind] = []
	var size := _rng.randf_range(0.8, 1.2)
	(lists[kind] as Array).append(Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3.ONE * size), at + Vector3.DOWN * 0.05))
	var gen: BrambleGen = _bramble_gens[kind]
	_thickets.append(Vector3(at.x, at.z, gen.radius * size * 0.6))


func _build() -> void:
	for cell: Vector2i in _patches:
		var data: Dictionary = _patches[cell]
		var patch := Node3D.new()
		patch.name = "Plants_%d_%d" % [cell.x, cell.y]
		var middle := (Vector2(cell) + Vector2(0.5, 0.5)) * PATCH
		patch.position = Vector3(middle.x, _lawn.height(middle) if _lawn.mask(middle) >= 0.0 else 0.0, middle.y)
		add_child(patch)
		for kind: String in data["flowers"]:
			if not _flower_gens.has(kind):
				_flower_gens[kind] = FlowerGen.preset(kind)
			var places := _local(patch, data["flowers"][kind])
			# (one draw a kind a patch: each patch its own seed of it, so neighbours differ)
			PlantLook.scatter(patch, places, (_flower_gens[kind] as FlowerGen).variant(absi(cell.x * 7 + cell.y * 13) % 3), FAR_FLOWERS)
		for kind: String in data["brambles"]:
			var places := _local(patch, data["brambles"][kind])
			BrambleGen.scatter(patch, places, _bramble_gens[kind], 1, FAR_BRAMBLES, false)
		if not (data["under"] as Array).is_empty():
			var under := Undergrowth.new()
			for item: Array in data["under"]:
				var where: Transform3D = item[1]
				under.add(item[0], Transform3D(where.basis, where.origin - patch.position))
			patch.add_child(under)
			under.build()
			# (Warren's draws to 110 m in its mist; here they go sooner)
			for shown in under.get_children():
				if shown is MultiMeshInstance3D:
					(shown as MultiMeshInstance3D).visibility_range_end = FAR_FERNS
					(shown as MultiMeshInstance3D).visibility_range_end_margin = 6.0
		_shown[cell] = patch


func _local(patch: Node3D, list: Array) -> Array:
	var places: Array = []
	for where: Transform3D in list:
		places.append(Transform3D(where.basis, where.origin - patch.position))
	return places


## How many of each (for a test): [ferns and low plants, flower clumps, brambles].
func counts() -> Vector3i:
	var made := Vector3i.ZERO
	for cell: Vector2i in _patches:
		var data: Dictionary = _patches[cell]
		made.x += (data["under"] as Array).size()
		for kind: String in data["flowers"]:
			made.y += (data["flowers"][kind] as Array).size()
		for kind: String in data["brambles"]:
			made.z += (data["brambles"][kind] as Array).size()
	return made


func _process(delta: float) -> void:
	# The wind and who pushes through them, to the shared look (once a frame)
	var wind_dir := Vector2(1.0, 0.0)
	var gust := 0.3
	if world.wind:
		wind_dir = world.wind.dir()
		var him := world.player.global_position
		gust = world.wind.gust(Vector2(him.x, him.z))
	PlantLook.update(get_viewport(), wind_dir, gust)
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
