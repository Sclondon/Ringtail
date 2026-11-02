class_name HazardCar
extends AnimatableBody3D
## A vehicle (models/vehicle_<kind>.glb, tools/build_vehicles.py) driving round a road loop on the left, as in Japan
## (Hazards gives it the lane). Kinds: a hatchback, a taxi, a kei truck, a kei van and a city bus, each its own size and pace
## (the user, 2026-11-02: "the roads should be wider, the cars bigger and faster" / "and there should be different
## types, busses etc"). It slows for corners, keeps back from whatever is ahead of it on the same road, and now and
## then stops a moment as at a junction; a bus stops longer, at its stops. Run into by its front, the raccoon is hurt
## and thrown; he can jump onto its roof and ride. Claude's picks: the kinds, speeds, stops, colours.

## Each kind: its model, its size (width, height to the roof, length), cruising and cornering speeds (m/s), and the
## radius of its wheels.
const KINDS := {
	&"hatchback": {"size": Vector3(1.7, 1.48, 4.05), "cruise": 11.0, "corner": 4.5, "wheel": 0.33},
	&"taxi": {"size": Vector3(1.7, 1.45, 4.65), "cruise": 11.5, "corner": 4.5, "wheel": 0.33},
	&"kei_truck": {"size": Vector3(1.48, 1.8, 3.42), "cruise": 9.5, "corner": 4.0, "wheel": 0.29},
	&"kei_van": {"size": Vector3(1.48, 1.88, 3.42), "cruise": 9.5, "corner": 4.0, "wheel": 0.29},
	&"bus": {"size": Vector3(2.5, 3.05, 10.55), "cruise": 7.5, "corner": 3.0, "wheel": 0.48},
}
## Room kept to whatever is ahead on the road (m), on top of a second's run at its speed.
const GAP := 3.0

var kind := &"hatchback"
var route := PackedVector3Array()
## Which road it is on (cars keep back only from those on the same road), and where on the loop it starts, 0..1.
var road := 0
var start := 0.0
var paint := Color(0.85, 0.22, 0.18)
## A second colour (the bus's lower half, the taxi's band): `paint` and this, by material.
var paint2 := Color(0.93, 0.9, 0.8)
var player: Player
var cruise := 11.0
var corner_speed := 4.5
## Half its size (width, height, length): what it fills, for anything that would be run over (Villager, SquadRaccoon).
var half_size := Vector3(0.85, 0.74, 2.0)
## Where along the loop a bus stops (m), if the road has stops (bus_stop_<n> markers near it).
var stops: Array[float] = []

var along := 0.0
var speed := 0.0
var _lengths := PackedFloat32Array()
var _total := 0.0
var _wheels: Array[Node3D] = []
var _wheel_radius := 0.33
var _stop_left := 0.0
var _stop_wait := randf_range(10.0, 22.0)
var _hurt_rest := 0.0
var _stopped_at := -1.0


func _ready() -> void:
	add_to_group(&"hazards")
	add_to_group(&"cars")
	sync_to_physics = true
	collision_layer = 1
	collision_mask = 0
	var spec: Dictionary = KINDS.get(kind, KINDS[&"hatchback"])
	var size: Vector3 = spec["size"]
	half_size = size * 0.5
	cruise = spec["cruise"] * randf_range(0.92, 1.06)
	corner_speed = spec["corner"]
	_wheel_radius = spec["wheel"]
	var model: Node3D = (load("res://models/vehicle_%s.glb" % kind) as PackedScene).instantiate()
	add_child(model)
	Toon.apply(model, {"paint": paint, "paint2": paint2})
	for node: Node in model.find_children("*", "Node3D", true, false):
		if String(node.name).contains("_wheel_"):
			_wheels.append(node)
	# A body to stand on: one box to its roof (its roof is flat enough), under the wheels' tops a little lifted off
	# the road so it does not catch the kerbs
	var shape := BoxShape3D.new()
	shape.size = Vector3(size.x, size.y - 0.3, size.z)
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.position = Vector3(0.0, 0.3 + (size.y - 0.3) * 0.5, 0.0)
	add_child(collider)
	_measure()
	along = start * _total
	_place(0.0)


func _measure() -> void:
	_lengths.clear()
	_total = 0.0
	var n := route.size()
	for i in n:
		var length := route[i].distance_to(route[(i + 1) % n])
		_lengths.append(length)
		_total += length


## How long its loop is (m).
func loop_length() -> float:
	return _total


## Where on the loop `distance` along it is, and the way it runs there.
func point_at(distance: float) -> Array:
	var d := fposmod(distance, maxf(_total, 0.001))
	var n := route.size()
	for i in n:
		if d <= _lengths[i] or i == n - 1:
			var a := route[i]
			var b := route[(i + 1) % n]
			return [a.lerp(b, clampf(d / maxf(_lengths[i], 0.001), 0.0, 1.0)), (b - a).normalized()]
		d -= _lengths[i]
	return [route[0], Vector3.FORWARD]


func _physics_process(delta: float) -> void:
	if route.size() < 2:
		return
	_hurt_rest = maxf(_hurt_rest - delta, 0.0)
	# How sharp the bend ahead is: it slows for it
	var here: Array = point_at(along)
	var ahead: Array = point_at(along + 5.0 + half_size.z)
	var bend := (here[1] as Vector3).angle_to(ahead[1])
	var want := lerpf(cruise, corner_speed, clampf(bend / 1.0, 0.0, 1.0))
	# ...now and then it stops: a bus at its stops (or every so often), anything else as at a junction
	if kind == &"bus" and not stops.is_empty():
		for at in stops:
			var to := fposmod(at - along, _total)
			if to < 0.6 and absf(_stopped_at - at) > 0.01 and _stop_left <= 0.0:
				_stop_left = randf_range(4.0, 6.0)
				_stopped_at = at
	else:
		_stop_wait -= delta
		if _stop_wait <= 0.0:
			_stop_left = randf_range(4.0, 6.0) if kind == &"bus" else randf_range(1.5, 3.0)
			_stop_wait = randf_range(14.0, 24.0) if kind == &"bus" else randf_range(12.0, 25.0)
	if _stop_left > 0.0:
		_stop_left -= delta
		want = 0.0
	# ...and keeps back from whatever is ahead of it on its road
	want = minf(want, _room_ahead())
	speed = move_toward(speed, want, (3.5 if want > speed else 9.0) * delta)
	along = fposmod(along + speed * delta, _total)
	_place(delta)
	_bump()


## The speed it may go at for what is ahead of it on its road: closing on the one in front, to its speed at GAP.
func _room_ahead() -> float:
	var most := INF
	for node in get_tree().get_nodes_in_group(&"cars"):
		var other := node as HazardCar
		if other == null or other == self or other.road != road:
			continue
		var gap := fposmod(other.along - along, _total) - half_size.z - other.half_size.z
		# (closing on it no faster than the room left allows: at GAP it goes as fast as the one in front)
		most = minf(most, other.speed + maxf(gap - GAP, 0.0) * 1.5)
	return most


func _place(delta: float) -> void:
	var at: Array = point_at(along)
	# (it turns as the road does, looking a little ahead so it rounds the corners; a long one looks further)
	var reach := 1.0 + half_size.z * 0.4
	var look: Vector3 = (point_at(along + reach)[0] as Vector3) - (point_at(along - reach)[0] as Vector3)
	look.y = 0.0
	var yaw := atan2(look.x, look.z) if look.length() > 0.01 else rotation.y
	global_transform = Transform3D(Basis(Vector3.UP, yaw), at[0])
	for wheel in _wheels:
		wheel.rotation.x += speed * delta / _wheel_radius


## Run into by its front: hurt and thrown aside.
func _bump() -> void:
	if player == null or _hurt_rest > 0.0 or speed < 1.0:
		return
	var local := global_transform.affine_inverse() * player.global_position
	# (in front of it, at road level: not on its roof)
	if absf(local.x) < half_size.x + 0.15 and local.z > half_size.z - 0.4 and local.z < half_size.z + 0.9 and local.y < 1.0:
		_hurt_rest = 1.0
		Hazards.hurt(self, global_position)
		var away := global_basis.z * (6.0 + speed * 0.4) + global_basis.x * signf(local.x if local.x != 0.0 else 1.0) * 3.0
		player.velocity = Vector3(away.x, 6.0, away.z)
