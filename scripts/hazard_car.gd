class_name HazardCar
extends AnimatableBody3D
## A cartoon car (models/car.glb, tools/build_hazards.py) driving round a road loop on the right (Hazards gives it
## the lane). It slows for corners and now and then stops a moment, as if at a junction. Run into by its front (or
## its back, reversing never: it only goes forward), the raccoon is hurt and thrown; he can jump onto its roof and
## ride. Claude's picks: speeds, stops, colours.

var route := PackedVector3Array()
## Where on the loop it starts, 0..1.
var start := 0.0
var paint := Color(0.85, 0.22, 0.18)
var player: Player
var cruise := 6.5
var corner_speed := 3.0

var along := 0.0
var speed := 0.0
var _lengths := PackedFloat32Array()
var _total := 0.0
var _wheels: Array[Node3D] = []
var _stop_left := 0.0
var _stop_wait := randf_range(10.0, 22.0)
var _hurt_rest := 0.0


func _ready() -> void:
	add_to_group(&"hazards")
	add_to_group(&"cars")
	sync_to_physics = true
	collision_layer = 1
	collision_mask = 0
	var model: Node3D = (load("res://models/car.glb") as PackedScene).instantiate()
	add_child(model)
	Toon.apply(model, {"paint": paint})
	for node: Node in model.find_children("*", "Node3D", true, false):
		if String(node.name).begins_with("car_wheel"):
			_wheels.append(node)
	# A body to stand on (the roof is flat at 1.47 m) and a cabin
	for box: Array in [[Vector3(0.0, 0.62, 0.0), Vector3(1.6, 0.62, 3.6)], [Vector3(0.0, 1.18, -0.42), Vector3(1.3, 0.58, 1.3)]]:
		var shape := BoxShape3D.new()
		shape.size = box[1]
		var collider := CollisionShape3D.new()
		collider.shape = shape
		collider.position = box[0]
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
	var ahead: Array = point_at(along + 5.0)
	var bend := (here[1] as Vector3).angle_to(ahead[1])
	var want := lerpf(cruise, corner_speed, clampf(bend / 1.2, 0.0, 1.0))
	# ...and now and then it stops, as at a junction
	_stop_wait -= delta
	if _stop_wait <= 0.0:
		_stop_left = randf_range(1.5, 3.0)
		_stop_wait = randf_range(12.0, 25.0)
	if _stop_left > 0.0:
		_stop_left -= delta
		want = 0.0
	speed = move_toward(speed, want, (4.0 if want > speed else 7.0) * delta)
	along = fposmod(along + speed * delta, _total)
	_place(delta)
	_bump()


func _place(delta: float) -> void:
	var at: Array = point_at(along)
	# (it turns as the road does, looking a little ahead so it rounds the corners)
	var look: Vector3 = (point_at(along + 1.6)[0] as Vector3) - (point_at(along - 1.6)[0] as Vector3)
	look.y = 0.0
	var yaw := atan2(look.x, look.z) if look.length() > 0.01 else rotation.y
	global_transform = Transform3D(Basis(Vector3.UP, yaw), at[0])
	for wheel in _wheels:
		wheel.rotation.x += speed * delta / 0.38


## Run into by its front: hurt and thrown aside.
func _bump() -> void:
	if player == null or _hurt_rest > 0.0 or speed < 1.0:
		return
	var local := global_transform.affine_inverse() * player.global_position
	# (in front of the bonnet, at road level: not on its roof)
	if absf(local.x) < 1.05 and local.z > 1.2 and local.z < 2.4 and local.y < 1.0:
		_hurt_rest = 1.0
		Hazards.hurt(self, global_position)
		var away := global_basis.z * 6.0 + global_basis.x * signf(local.x if local.x != 0.0 else 1.0) * 3.0
		player.velocity = Vector3(away.x, 6.0, away.z)
