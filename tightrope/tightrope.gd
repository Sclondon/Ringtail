class_name Tightrope
extends Node3D
## A line strung from `from` to `to` (both in the world) to walk along as a tightrope: it sags, dips under whoever
## stands on it, and sways and settles after; he is drawn back over its line while he stands on it and is not
## stepping off, and balances on it (arms out, one foot before the other: the character controller's rig).
## Duck on it and he lets himself down to hang under it by his hands; left and right take him along it hand over
## hand; jump pulls him back up onto it; he catches it from a jump. From Warren (The Clearing): its RopeBridge
## chain and its VineStrand, made to stand alone (GameCommon, 2026-11-01).
##
## Looks: `style` WIRE (a thin dark cable) or VINE (a green stem with leaves).
##
## Needs GameCommon's godot/character-controller (its Player walks it and hangs from it: Player.tightrope,
## tightrope_on, _try_catch_strand ...; and joins the group `tightrope_walkers`, whose members weigh on it).

enum Style { WIRE, VINE }

## The points of its chain, and how much of its stretch each pass of the solver takes back.
const POINTS := 15
const STIFF := 0.7
## How far either side of its line his feet stay on it, metres, and how quickly he is drawn back over it.
const FOOTING := 0.17
const BALANCE := 7.0
## Within this of its line someone wakes it; within BODIES_NEAR it has bodies to stand on, past BODIES_GONE none.
const WAKE := 4.0
const BODIES_NEAR := 36.0
const BODIES_GONE := 48.0

@export var from := Vector3.ZERO
@export var to := Vector3(6, 0, 0)
## How much longer than the gap it is at most, and how far it sags at most, metres (a long one is strung tighter).
@export var slack := 1.05
@export var most_sag := 2.2
## How heavy someone is, against its own weight per point.
@export var weight := 9.0
@export var style := Style.WIRE
## The cable's or the stem's colour, and radius.
@export var colour := Color(0.1, 0.09, 0.09)
@export var thickness := 0.025

var _points := PackedVector3Array()
var _before := PackedVector3Array()
var _piece := 0.0
var _bodies: Array[AnimatableBody3D] = []
var _look_in := 0.0
var _strands: MultiMeshInstance3D
var _leaves: MultiMeshInstance3D
var _leaf_places: Array = []


func _ready() -> void:
	add_to_group(&"tightropes")
	# (a shallow curve sags by about sqrt(3 / 8 * gap * extra length))
	var gap := from.distance_to(to)
	_piece = gap * minf(slack, 1.0 + 8.0 / 3.0 * pow(most_sag / maxf(gap, 0.01), 2.0)) / (POINTS - 1)
	# Hung as it will settle: a curve as deep as its length makes it
	var sag := sqrt(3.0 / 8.0 * gap * maxf(_piece * (POINTS - 1) - gap, 0.0))
	for i in POINTS:
		var t := float(i) / (POINTS - 1)
		_points.append(from.lerp(to, t) + Vector3.DOWN * 4.0 * t * (1.0 - t) * sag)
	_before = _points.duplicate()
	_strands = _many(_cable(), POINTS - 1)
	if style == Style.VINE:
		_grow_leaves()
	_lay()


func _cable() -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = thickness if style == Style.WIRE else maxf(thickness, 0.04)
	mesh.bottom_radius = mesh.top_radius
	mesh.height = 1.0
	mesh.radial_segments = 6
	mesh.rings = 1
	var material := StandardMaterial3D.new()
	material.albedo_color = colour if style == Style.WIRE else Color(0.2, 0.24, 0.12)
	material.roughness = 0.8
	mesh.material = material
	return mesh


func _many(mesh: Mesh, count: int) -> MultiMeshInstance3D:
	var many := MultiMesh.new()
	many.transform_format = MultiMesh.TRANSFORM_3D
	many.mesh = mesh
	many.instance_count = count
	var shown := MultiMeshInstance3D.new()
	shown.multimesh = many
	shown.top_level = true
	add_child(shown)
	shown.global_transform = Transform3D.IDENTITY
	return shown


## Leaves along a vine: little green cards out to either side, faces up.
func _grow_leaves() -> void:
	var leaf := QuadMesh.new()
	leaf.size = Vector2(0.12, 0.2)
	leaf.center_offset = Vector3(0.0, 0.1, 0.0)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.3, 0.5, 0.2)
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.roughness = 1.0
	leaf.material = material
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(from.snappedf(0.01))
	var each := maxi(3, roundi(_piece / 0.12))
	_leaves = _many(leaf, (POINTS - 1) * each)
	for i in (POINTS - 1) * each:
		_leaf_places.append([i / each, rng.randf(), rng.randf_range(-0.9, 0.9) + (PI if rng.randf() < 0.5 else 0.0), rng.randf_range(0.7, 1.2)])


func _physics_process(delta: float) -> void:
	_look_in -= delta
	if _look_in <= 0.0:
		_look_in = 0.5
		_keep_bodies()
	var middle := POINTS / 2
	var anyone := _anyone_within(WAKE)
	# (hanging still with nobody by it, it rests)
	if (_points[middle] - _before[middle]).length_squared() < 0.000001 and not anyone:
		return
	var gravity := Vector3.DOWN * 9.8
	var pull := []
	pull.resize(POINTS)
	pull.fill(0.0)
	for body: Node in get_tree().get_nodes_in_group(&"tightrope_walkers"):
		var i := _nearest((body as Node3D).global_position)
		if i >= 0:
			pull[i] += 1.0
	# A step of the chain: each point carries on as it was going, falls, and is drawn down by anyone on it near it
	for i in range(1, POINTS - 1):
		var p := _points[i]
		var moving := (p - _before[i]) * 0.985
		_before[i] = p
		_points[i] = p + moving + (gravity * (1.0 + float(pull[i]) * weight)) * delta * delta
	# Then held to its length, again and again, but not quite: it gives a little, most where the weight is
	for k in 6:
		_points[0] = from
		_points[POINTS - 1] = to
		for i in POINTS - 1:
			var a := _points[i]
			var b := _points[i + 1]
			var gap := b - a
			var length := gap.length()
			if length < 0.0001:
				continue
			var fix := gap * (1.0 - _piece / length) * 0.5 * STIFF
			if i > 0:
				_points[i] = a + fix
			if i + 1 < POINTS - 1:
				_points[i + 1] = b - fix
	_lay()
	# Whoever stands on it is drawn back over it, unless he is stepping off, and balances on it
	for body: Node in get_tree().get_nodes_in_group(&"tightrope_walkers"):
		var walker := body as CharacterBody3D
		if walker == null or not walker.is_on_floor() or not _carries(walker.global_position):
			continue
		var off := walker.global_position - _closest(walker.global_position)
		off.y = 0.0
		var across := line().cross(Vector3.UP)
		var aside := off.dot(across)
		var stepping := Vector3(walker.velocity.x, 0.0, walker.velocity.z).dot(across * signf(aside))
		if absf(aside) < 0.6 and stepping < 2.5:
			walker.global_position -= across * aside * minf(1.0, BALANCE * delta)
		if absf(aside) < 0.6 and &"tightrope" in walker:
			walker.set(&"tightrope", 0.2)
			walker.set(&"tightrope_aside", aside * signf(across.dot(walker.global_basis.x)))
			walker.set(&"tightrope_on", self)


func _anyone_within(reach: float) -> bool:
	for body: Node in get_tree().get_nodes_in_group(&"tightrope_walkers"):
		if reach_to((body as Node3D).global_position) < reach:
			return true
	return false


## The point of the chain someone at `at` is standing on, or -1.
func _nearest(at: Vector3) -> int:
	var best := -1
	var best_distance := 0.9
	for i in range(1, POINTS - 1):
		var p := _points[i]
		var level := Vector2(at.x - p.x, at.z - p.z).length()
		if level < FOOTING * 2.0 and at.y > p.y - 0.3 and at.y < p.y + 0.8 and level < best_distance + FOOTING:
			best = i
			best_distance = level
	return best


func _lay() -> void:
	var side := line().cross(Vector3.UP)
	for i in POINTS - 1:
		var a := _points[i]
		var b := _points[i + 1]
		if not _bodies.is_empty():
			_bodies[i].global_transform = _piece_at(i, side)
		var along := b - a
		var y := along.normalized()
		var x := y.cross(Vector3.FORWARD if absf(y.z) < 0.9 else Vector3.RIGHT).normalized()
		_strands.multimesh.set_instance_transform(i, Transform3D(Basis(x, y * along.length(), x.cross(y)), (a + b) * 0.5))
	if _leaves:
		for i in _leaf_places.size():
			var place: Array = _leaf_places[i]
			var a := _points[place[0]]
			var b := _points[place[0] + 1]
			var along := (b - a).normalized()
			var out := side.rotated(along, place[2])
			var face := along.cross(out)
			if face.y < 0.0:
				face = -face
			var y := (out * 0.95 - face * 0.3).normalized()
			var z := y.cross(along).normalized()
			_leaves.multimesh.set_instance_transform(i, Transform3D(Basis(y.cross(z), y, z).scaled(Vector3.ONE * place[3]), a.lerp(b, place[1]) + out * 0.04))


## Where piece `i` lies (`side` the way across it), for its body to stand on.
func _piece_at(i: int, side: Vector3) -> Transform3D:
	var a := _points[i]
	var b := _points[i + 1]
	var along := (b - a).normalized()
	var up := side.cross(along).normalized() * -1.0
	if up.y < 0.0:
		up = -up
	return Transform3D(Basis(side, up, along).orthonormalized(), (a + b) * 0.5)


## Bodies to stand on (a thin plank a piece, FOOTING either side of its line) while someone is near enough.
func _keep_bodies() -> void:
	var near := INF
	for body: Node in get_tree().get_nodes_in_group(&"tightrope_walkers"):
		near = minf(near, reach_to((body as Node3D).global_position))
	if near < BODIES_NEAR and _bodies.is_empty() and is_inside_tree():
		var box := BoxShape3D.new()
		box.size = Vector3(FOOTING * 2.0, 0.12, _piece * 1.02)
		var side := line().cross(Vector3.UP)
		for i in POINTS - 1:
			var plank := AnimatableBody3D.new()
			plank.top_level = true
			plank.sync_to_physics = true
			var shape := CollisionShape3D.new()
			shape.shape = box
			# (its top along the line itself)
			shape.position.y = -0.06
			plank.add_child(shape)
			plank.transform = _piece_at(i, side)
			add_child(plank)
			_bodies.append(plank)
	elif near > BODIES_GONE and not _bodies.is_empty():
		for plank in _bodies:
			plank.queue_free()
		_bodies.clear()


## Makes its bodies now if anyone is near enough (for a test, or after putting someone down somewhere new).
func bodies_now() -> void:
	_keep_bodies()


# --- Where it is (the Player asks these to walk it and hang from it) ---

## How far `point` is from the straight line between its ends (it sags a little under that).
func reach_to(point: Vector3) -> float:
	var span_now := to - from
	var t := clampf((point - from).dot(span_now) / maxf(span_now.length_squared(), 0.0001), 0.0, 1.0)
	return (from + span_now * t).distance_to(point)


## Which way it runs across the ground, from `from` to `to` (level, unit length).
func line() -> Vector3:
	var along := to - from
	along.y = 0.0
	return along.normalized() if along.length_squared() > 0.000001 else Vector3.RIGHT


## How far it runs across the ground, metres.
func span() -> float:
	return Vector2(to.x - from.x, to.z - from.z).length()


## How far along it, across the ground from `from`, a point is.
func distance_along(point: Vector3) -> float:
	return clampf((point - from).dot(line()), 0.0, span())


## The point of it (as it hangs now) `distance` metres along it across the ground.
func point_at_distance(distance: float) -> Vector3:
	var span_now := maxf(span(), 0.001)
	var t := clampf(distance / span_now, 0.0, 1.0) * (POINTS - 1)
	var i := mini(int(t), POINTS - 2)
	var level := from + line() * distance
	var y := lerpf(_points[i].y, _points[i + 1].y, t - i)
	return Vector3(level.x, y, level.z)


## The point of it nearest `point`.
func point_near(point: Vector3) -> Vector3:
	return _closest(point)


## How far a point is from it.
func distance_to(point: Vector3) -> float:
	return _closest(point).distance_to(point)


func _closest(point: Vector3) -> Vector3:
	var best := _points[0]
	for i in POINTS - 1:
		var a := _points[i]
		var ab := _points[i + 1] - a
		var t := clampf((point - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
		var p := a + ab * t
		if p.distance_squared_to(point) < best.distance_squared_to(point):
			best = p
	return best


## Whether someone whose feet are at `feet` is stood on it: over its line, on it, not under it or well over it.
func carries(feet: Vector3) -> bool:
	return _carries(feet)


func _carries(feet: Vector3) -> bool:
	var on := _closest(feet)
	var level := Vector2(feet.x - on.x, feet.z - on.z).length()
	return level < 0.6 and feet.y > on.y - 0.3 and feet.y < on.y + 0.8
