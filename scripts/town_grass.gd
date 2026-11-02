class_name TownGrass
extends RefCounted
## Gloaming's grass (GameCommon godot/grass) over the town's lawns (the user, 2026-11-02: "lets add the gloaming
## grass as well"): wherever the world model's ground is the "grass" material and nothing lies over it (the road,
## a pavement, a house). Heights are the ground's own, triangle by triangle. Also hands out lawn spots (Wildlife).
##
##   var lawn := TownGrass.place(world, player)
##
## Working the lawn out walks every triangle of the town (seconds natively, much longer in a browser), so it is kept
## in LAWN_FILE, with a fingerprint of everything it was worked out from; a start whose world matches reads it back
## instead. A run from the editor (the tests too) writes it whenever it had to work it out: commit it with the world.

## Cells (metres) the lawn is kept in.
const CELL := 0.5
## The lawn kept for the start (see above).
const LAWN_FILE := "res://models/world1.lawn"

## The cells' grid: its first cell and how many across (x) and down (z).
var _origin := Vector2i.ZERO
var _size := Vector2i.ZERO
## Each cell's plane of the grass (y = x * a + z * b + c: a, b, c in turn), c NAN where there is no grass.
var _plane := PackedFloat32Array()
## Each cell's state: 0 not yet known, COVERED (something lies over the grass), OPEN (found clear the first time
## it was asked).
var _state := PackedByteArray()
const COVERED := 1
const OPEN := 2
## How many cells have grass.
var _grassy := 0
## The grassy cells' indices, in the order they were laid (random_spot picks from them, as it always has).
var _order := PackedInt32Array()
var _space: PhysicsDirectSpaceState3D
## Reed patches: (x, z, radius).
var _patches: Array[Vector3] = []
## Tall grass patches to hide in: (x, z, radius).
var _tall: Array[Vector3] = []
## The lawn of the world now (for `hidden`).
static var current: TownGrass


static func place(world: Node3D, player: Node3D, markers := {}) -> TownGrass:
	var lawn := TownGrass.new()
	lawn._space = world.get_world_3d().direct_space_state
	# (what can cover the lawn: everything but what moves about)
	var meshes: Array[MeshInstance3D] = []
	for mesh: MeshInstance3D in world.find_children("*", "MeshInstance3D", true, false):
		if mesh.mesh != null and _still(mesh, world):
			meshes.append(mesh)
	var print_of := _fingerprint(meshes)
	if not lawn._read(print_of):
		lawn._work_out(meshes)
		if OS.has_feature("editor"):
			lawn._write(print_of)
	World.lap("  lawn")
	if lawn._grassy == 0:
		return lawn
	var field := Grass.field(world, lawn._bounds(), 2.0, {
		"mask": lawn.mask,
		"height": lawn.height,
		"ground": lawn._ground_colour(),
		"flowers": 0.03,
		# (grass to a raccoon's scale: about knee high on a person, so up to his chest)
		"blade_height": 0.24,
		"blade_width": 0.022,
		"seed": 7,
	})
	# (the field holds on to it: its mask and height are calls on it, and nothing else keeps it)
	field.set_meta(&"lawn", lawn)
	lawn._grow_reeds(world, markers)
	lawn._grow_tall(world, markers)
	current = lawn
	Grass.push(player)
	return lawn


## Whether `mesh` stays put (not on anything that moves: a creature, a car, a body knocked about).
static func _still(mesh: Node, world: Node) -> bool:
	var up := mesh.get_parent()
	while up != null and up != world:
		if up is CharacterBody3D or up is RigidBody3D or up is Skeleton3D or up is AnimatableBody3D or up is Area3D:
			return false
		up = up.get_parent()
	return true


## What the lawn is worked out from, in short: every mesh's place, size and surfaces.
static func _fingerprint(meshes: Array[MeshInstance3D]) -> String:
	var parts := PackedStringArray()
	for mesh in meshes:
		var box := mesh.global_transform * mesh.get_aabb()
		# (small things, settling a little differently each start, matter little to the lawn)
		if box.get_longest_axis_size() < 1.0:
			continue
		var surfaces := mesh.mesh.get_class()
		if not mesh.mesh is ArrayMesh:
			parts.append("%s|%s|%s" % [str(box.position.snappedf(0.1)), str(box.size.snappedf(0.1)), surfaces])
			continue
		for k in mesh.mesh.get_surface_count():
			var material := mesh.mesh.surface_get_material(k)
			surfaces += "%d%s," % [(mesh.mesh as ArrayMesh).surface_get_array_len(k), "g" if material != null and material.resource_name == "grass" else ""]
		parts.append("%s|%s|%s" % [str(box.position.snappedf(0.1)), str(box.size.snappedf(0.1)), surfaces])
	parts.sort()
	return "%d:%s" % [CELL * 1000, "\n".join(parts).sha256_text()]


## The lawn from LAWN_FILE, if it was worked out from this world (`print_of`).
func _read(print_of: String) -> bool:
	var file := FileAccess.open_compressed(LAWN_FILE, FileAccess.READ, FileAccess.COMPRESSION_ZSTD)
	if file == null:
		return false
	var kept: Variant = file.get_var()
	if not (kept is Dictionary) or kept.get("print", "") != print_of or not kept.has_all(["origin", "size", "plane", "state", "order"]):
		return false
	_origin = kept["origin"]
	_size = kept["size"]
	_plane = kept["plane"]
	_state = kept["state"]
	_order = kept["order"]
	_grassy = _order.size()
	return _plane.size() == _size.x * _size.y * 3 and _state.size() == _size.x * _size.y


func _write(print_of: String) -> void:
	var file := FileAccess.open_compressed(LAWN_FILE, FileAccess.WRITE, FileAccess.COMPRESSION_ZSTD)
	if file == null:
		push_warning("TownGrass: cannot write %s" % LAWN_FILE)
		return
	file.store_var({"print": print_of, "origin": _origin, "size": _size, "plane": _plane, "state": _state, "order": _order})


## Works the lawn out from the meshes: their "grass" surfaces lay it, triangle by triangle; then whatever is laid over
## it (the road and pavement rings, paths, floors) covers it.
func _work_out(meshes: Array[MeshInstance3D]) -> void:
	# (the grid: round every mesh with grass)
	var area := Rect2()
	var any := false
	for mesh in meshes:
		for k in mesh.mesh.get_surface_count():
			var material := mesh.mesh.surface_get_material(k)
			if material != null and material.resource_name == "grass":
				var box := mesh.global_transform * mesh.get_aabb()
				var flat := Rect2(box.position.x, box.position.z, box.size.x, box.size.z)
				area = area.merge(flat) if any else flat
				any = true
				break
	if not any:
		return
	_origin = Vector2i((area.position / CELL).floor())
	_size = Vector2i((area.end / CELL).floor()) - _origin + Vector2i.ONE
	_plane.resize(_size.x * _size.y * 3)
	for i in _size.x * _size.y:
		_plane[i * 3 + 2] = NAN
	_state.resize(_size.x * _size.y)
	_state.fill(0)
	for mesh in meshes:
		_scan(mesh, true)
	for mesh in meshes:
		var box := mesh.global_transform * mesh.get_aabb()
		# (only what reaches over the lawn's grid: the far mountains' and ridges' huge triangles walked millions of
		# empty cells, 20 s of the start-up)
		if box.position.x > area.end.x or box.end.x < area.position.x or box.position.z > area.end.y or box.end.z < area.position.y:
			continue
		_scan(mesh, false, _ground_top(box))


## Reeds where the world model has `reeds_<n>` markers (scale.x the patch's radius): Warren's, its marsh's reed field
## (TheClearing scripts/marsh.gd; the user, 2026-11-02, "please dont make new reeds check the ones we already have"),
## on the lawn only.
func _grow_reeds(world: Node3D, markers: Dictionary) -> void:
	for name: String in markers:
		if name.begins_with("reeds_"):
			var at: Transform3D = markers[name]
			_patches.append(Vector3(at.origin.x, at.origin.z, maxf(at.basis.get_scale().x, 0.5)))
	if _patches.is_empty():
		return
	var reach := Rect2(Vector2(_patches[0].x, _patches[0].y), Vector2.ZERO)
	for patch in _patches:
		reach = reach.expand(Vector2(patch.x, patch.y) - Vector2.ONE * patch.z).expand(Vector2(patch.x, patch.y) + Vector2.ONE * patch.z)
	var reeds := Grass.field(world, reach, 0.8, {
		"mask": reeds_at,
		"height": height,
		"ground": Color(0.11, 0.14, 0.07),
		"blade_height": 0.95 * 1.8,
		"blade_width": 0.03,
		"lean": 0.12,
		"body": Color(0.15, 0.2, 0.09),
		"tip": Color(0.42, 0.4, 0.22),
		"dry": Color(0.48, 0.42, 0.24),
		"dryness": 0.45,
		"translucency": 0.1,
		"flowers": 0.0,
		"push_bend": 1.0,
		"seed": 3,
	})
	reeds.set_meta(&"lawn", self)


## Tall grass to hide in where the world model has `tallgrass_<n>` markers (scale.x the patch's radius): the same
## grass, but taller than he is and thick (the user, 2026-11-02, "tall grass to hide in in spots as well").
func _grow_tall(world: Node3D, markers: Dictionary) -> void:
	for name: String in markers:
		if name.begins_with("tallgrass_"):
			var at: Transform3D = markers[name]
			_tall.append(Vector3(at.origin.x, at.origin.z, maxf(at.basis.get_scale().x, 0.5)))
	if _tall.is_empty():
		return
	var reach := Rect2(Vector2(_tall[0].x, _tall[0].y), Vector2.ZERO)
	for patch in _tall:
		reach = reach.expand(Vector2(patch.x, patch.y) - Vector2.ONE * patch.z).expand(Vector2(patch.x, patch.y) + Vector2.ONE * patch.z)
	# (thick: dense clumps to vanish into; the user, 2026-11-02, "the tall grass areas need to have denser clusters")
	var tall := Grass.field(world, reach, 6.5, {
		"mask": tall_at,
		"height": height,
		"ground": _ground_colour(),
		"blade_height": 0.85,
		"blade_width": 0.036,
		"lean": 0.18,
		"dryness": 0.35,
		"flowers": 0.02,
		"push_bend": 0.9,
		"seed": 5,
	})
	tall.set_meta(&"lawn", self)


## Tall grass at `p`: in a patch (thinning at its edge) and on open lawn.
func tall_at(p: Vector2) -> float:
	var most := 0.0
	for patch in _tall:
		var d := Vector2(patch.x, patch.y).distance_to(p) / patch.z
		most = maxf(most, 1.0 - smoothstep(0.7, 1.0, d))
	return most * mask(p) if most > 0.0 else 0.0


## Whether `at` (someone's feet) is down in tall grass, well inside a patch: hidden there from what hunts him.
static func hidden(at: Vector3) -> bool:
	if current == null:
		return false
	var p := Vector2(at.x, at.z)
	if absf(at.y - current.height(p)) > 0.4:
		return false
	for patch in current._tall:
		if Vector2(patch.x, patch.y).distance_to(p) < patch.z * 0.75:
			return true
	return false


## Reeds at `p`: in a patch (thinning to its edge) and on open lawn.
func reeds_at(p: Vector2) -> float:
	var most := 0.0
	for patch in _patches:
		var d := Vector2(patch.x, patch.y).distance_to(p) / patch.z
		most = maxf(most, 1.0 - smoothstep(0.6, 1.0, d))
	return most * mask(p) if most > 0.0 else 0.0


## The grid's index of `cell`, or -1 off it.
func _at(cell: Vector2i) -> int:
	var x := cell.x - _origin.x
	var z := cell.y - _origin.y
	if x < 0 or z < 0 or x >= _size.x or z >= _size.y:
		return -1
	return z * _size.x + x


## Whether `cell` has grass.
func _grassed(i: int) -> bool:
	return i >= 0 and not is_nan(_plane[i * 3 + 2])


## 1 where grass grows at `p` (world x, z), else 0.
func mask(p: Vector2) -> float:
	var cell := Vector2i((p / CELL).floor())
	var i := _at(cell)
	if not _grassed(i):
		return 0.0
	if _state[i] == 0:
		_state[i] = COVERED if _is_covered(cell) else OPEN
	return 0.0 if _state[i] == COVERED else 1.0


## The ground's height at `p` (world x, z) where there is grass.
func height(p: Vector2) -> float:
	var i := _at(Vector2i((p / CELL).floor()))
	if not _grassed(i):
		return 0.0
	return p.x * _plane[i * 3] + p.y * _plane[i * 3 + 1] + _plane[i * 3 + 2]


## A spot on open lawn, or Vector3.INF if none is found.
func random_spot(rng: RandomNumberGenerator) -> Vector3:
	if _order.is_empty():
		return Vector3.INF
	for _try in 40:
		var i := _order[rng.randi() % _order.size()]
		var p := (Vector2(_origin + Vector2i(i % _size.x, i / _size.x)) + Vector2(0.5, 0.5)) * CELL
		if mask(p) > 0.5:
			return Vector3(p.x, height(p), p.y)
	return Vector3.INF


## Lays the "grass" surfaces of `mesh` into the lawn (`grass`), or covers the lawn under its other surfaces (those
## of them that come within 2.5 m of `ground_top`, the highest lawn under it).
func _scan(mesh: MeshInstance3D, grass: bool, ground_top := INF) -> void:
	var to_world := mesh.global_transform
	for k in mesh.mesh.get_surface_count():
		var material := mesh.mesh.surface_get_material(k)
		if (material != null and material.resource_name == "grass") != grass:
			continue
		var arrays := mesh.mesh.surface_get_arrays(k)
		var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var order: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		var count := order.size() if not order.is_empty() else points.size()
		for t in range(0, count - 2, 3):
			var a := to_world * points[order[t] if not order.is_empty() else t]
			var b := to_world * points[order[t + 1] if not order.is_empty() else t + 1]
			var c := to_world * points[order[t + 2] if not order.is_empty() else t + 2]
			# (nothing more than 2.5 m over the lawn covers it: most of a tree's crown)
			if minf(a.y, minf(b.y, c.y)) > ground_top + 2.5:
				continue
			_lay(a, b, c, grass)


## Marks the cells a ground triangle covers (by their middles), with its plane; or, not grass, marks lawn cells it
## lies on or just over as covered.
func _lay(a: Vector3, b: Vector3, c: Vector3, grass: bool) -> void:
	var normal := (b - a).cross(c - a)
	if absf(normal.y) < 0.0001:
		return
	# (the plane through them: y = x * px + z * pz + k)
	var plane := Vector3(-normal.x / normal.y, -normal.z / normal.y, 0.0)
	plane.z = a.y - a.x * plane.x - a.z * plane.y
	var low := Vector2i((Vector2(minf(a.x, minf(b.x, c.x)), minf(a.z, minf(b.z, c.z))) / CELL).floor()).max(_origin)
	var high := Vector2i((Vector2(maxf(a.x, maxf(b.x, c.x)), maxf(a.z, maxf(b.z, c.z))) / CELL).floor()).min(_origin + _size - Vector2i.ONE)
	if low.x > high.x or low.y > high.y:
		return
	var a2 := Vector2(a.x, a.z)
	var b2 := Vector2(b.x, b.z)
	var c2 := Vector2(c.x, c.z)
	for x in range(low.x, high.x + 1):
		for z in range(low.y, high.y + 1):
			var cell := Vector2i(x, z)
			var i := _at(cell)
			var p := (Vector2(x, z) + Vector2(0.5, 0.5)) * CELL
			if grass:
				if Geometry2D.point_is_inside_triangle(p, a2, b2, c2):
					if is_nan(_plane[i * 3 + 2]):
						_grassy += 1
						_order.append(i)
					_plane[i * 3] = plane.x
					_plane[i * 3 + 1] = plane.y
					_plane[i * 3 + 2] = plane.z
				continue
			# (anything else covers a cell it touches at all: its middle or a corner, so no tufts stand at a road's edge)
			if not _grassed(i) or _state[i] == COVERED:
				continue
			var touches := false
			for corner: Vector2 in [p, p + Vector2(-0.24, -0.24), p + Vector2(0.24, -0.24), p + Vector2(-0.24, 0.24), p + Vector2(0.24, 0.24)]:
				if Geometry2D.point_is_inside_triangle(corner, a2, b2, c2):
					touches = true
					break
			if touches:
				var over := p.x * plane.x + p.y * plane.y + plane.z - height(p)
				# (over it, or let into the ground below where the lawn would be: a road cut lower than the ground grid)
				if over > -0.6 and over < 2.5:
					_state[i] = COVERED


## The highest lawn under `box` (world), or INF over a big one (too many cells to look at: not worth it).
func _ground_top(box: AABB) -> float:
	var low := Vector2i((Vector2(box.position.x, box.position.z) / CELL).floor())
	var high := Vector2i((Vector2(box.end.x, box.end.z) / CELL).floor())
	if (high.x - low.x + 1) * (high.y - low.y + 1) > 6400:
		return INF
	var top := -INF
	for x in range(low.x, high.x + 1):
		for z in range(low.y, high.y + 1):
			var p := (Vector2(x, z) + Vector2(0.5, 0.5)) * CELL
			if _grassed(_at(Vector2i(x, z))):
				top = maxf(top, height(p))
	return top


## Whether anything solid lies over the grass in `cell` (a road ring laid over it, a house, a wall).
func _is_covered(cell: Vector2i) -> bool:
	var p := (Vector2(cell) + Vector2(0.5, 0.5)) * CELL
	var y := height(p)
	var query := PhysicsRayQueryParameters3D.create(Vector3(p.x, y + 4.0, p.y), Vector3(p.x, y - 0.3, p.y), 1)
	var hit := _space.intersect_ray(query)
	if hit.is_empty():
		return true
	# (the first thing met must be the lawn itself: not something on it, and not ground lower than it)
	return absf((hit.position as Vector3).y - y) > 0.05


func _bounds() -> Rect2:
	return Rect2(Vector2(_origin) * CELL, Vector2(_size) * CELL)


## The lawn texture's mean colour, for the blades' roots.
static func _ground_colour() -> Color:
	var texture := load("res://textures/grass.png") as Texture2D
	if texture == null:
		return Color(0.3, 0.42, 0.18)
	var image := texture.get_image()
	if image.is_compressed():
		image.decompress()
	image.resize(1, 1, Image.INTERPOLATE_BILINEAR)
	return image.get_pixel(0, 0)
