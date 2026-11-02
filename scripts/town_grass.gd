class_name TownGrass
extends RefCounted
## Gloaming's grass (GameCommon godot/grass) over the town's lawns (the user, 2026-11-02: "lets add the gloaming
## grass as well"): wherever the world model's ground is the "grass" material and nothing lies over it (the road,
## a pavement, a house). Heights are the ground's own, triangle by triangle. Also hands out lawn spots (Wildlife).
##
##   var lawn := TownGrass.place(world, player)

## Cells (metres) the lawn is kept in.
const CELL := 0.5

## Cell -> the plane of the grass there (y = x * a + z * b + c, as Vector3(a, b, c)).
var _planes := {}
## Cell -> whether something lies over the grass there (found out the first time it is asked).
var _covered := {}
var _space: PhysicsDirectSpaceState3D
## Reed patches: (x, z, radius).
var _patches: Array[Vector3] = []


static func place(world: Node3D, player: Node3D, markers := {}) -> TownGrass:
	var lawn := TownGrass.new()
	lawn._space = world.get_world_3d().direct_space_state
	var meshes := world.find_children("*", "MeshInstance3D", true, false)
	for mesh: MeshInstance3D in meshes:
		lawn._scan(mesh, true)
	# (then whatever is laid over the lawn: the road and pavement rings, paths, floors)
	for mesh: MeshInstance3D in meshes:
		lawn._scan(mesh, false)
	if lawn._planes.is_empty():
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
	Grass.push(player)
	return lawn


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


## Reeds at `p`: in a patch (thinning to its edge) and on open lawn.
func reeds_at(p: Vector2) -> float:
	var most := 0.0
	for patch in _patches:
		var d := Vector2(patch.x, patch.y).distance_to(p) / patch.z
		most = maxf(most, 1.0 - smoothstep(0.6, 1.0, d))
	return most * mask(p) if most > 0.0 else 0.0


## 1 where grass grows at `p` (world x, z), else 0.
func mask(p: Vector2) -> float:
	var cell := Vector2i((p / CELL).floor())
	if not _planes.has(cell):
		return 0.0
	if not _covered.has(cell):
		_covered[cell] = _is_covered(cell)
	return 0.0 if _covered[cell] else 1.0


## The ground's height at `p` (world x, z) where there is grass.
func height(p: Vector2) -> float:
	var plane: Vector3 = _planes.get(Vector2i((p / CELL).floor()), Vector3.ZERO)
	return p.x * plane.x + p.y * plane.y + plane.z


## A spot on open lawn, or Vector3.INF if none is found.
func random_spot(rng: RandomNumberGenerator) -> Vector3:
	var cells := _planes.keys()
	for _try in 40:
		var cell: Vector2i = cells[rng.randi() % cells.size()]
		var p := (Vector2(cell) + Vector2(0.5, 0.5)) * CELL
		if mask(p) > 0.5:
			return Vector3(p.x, height(p), p.y)
	return Vector3.INF


## Lays the "grass" surfaces of `mesh` into the lawn (`grass`), or covers the lawn under its other surfaces.
func _scan(mesh: MeshInstance3D, grass: bool) -> void:
	if mesh.mesh == null:
		return
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
	var low := Vector2i((Vector2(minf(a.x, minf(b.x, c.x)), minf(a.z, minf(b.z, c.z))) / CELL).floor())
	var high := Vector2i((Vector2(maxf(a.x, maxf(b.x, c.x)), maxf(a.z, maxf(b.z, c.z))) / CELL).floor())
	var a2 := Vector2(a.x, a.z)
	var b2 := Vector2(b.x, b.z)
	var c2 := Vector2(c.x, c.z)
	for x in range(low.x, high.x + 1):
		for z in range(low.y, high.y + 1):
			var cell := Vector2i(x, z)
			var p := (Vector2(x, z) + Vector2(0.5, 0.5)) * CELL
			if grass:
				if Geometry2D.point_is_inside_triangle(p, a2, b2, c2):
					_planes[cell] = plane
				continue
			# (anything else covers a cell it touches at all: its middle or a corner, so no tufts stand at a road's edge)
			if not _planes.has(cell):
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
					_covered[cell] = true


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
	var low := Vector2(INF, INF)
	var high := Vector2(-INF, -INF)
	for cell: Vector2i in _planes:
		low = low.min(Vector2(cell))
		high = high.max(Vector2(cell))
	return Rect2(low * CELL, (high - low + Vector2.ONE) * CELL)


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
