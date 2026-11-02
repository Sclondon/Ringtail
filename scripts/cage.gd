class_name Cage
extends StaticBody3D
## A cage a lost raccoon is shut in, to break open as in Rayman (the user, 2026-11-02: "they should be in cages you
## have to break like in rayman"). Solid (he can stand on it, not get in); his tail spin hits it (group
## `tail_hittable`), and every hit rattles it; the `HITS`th bursts it, its bars, posts, lid and lock thrown about in a
## puff of dust, and `broken` lets whoever was in it out. The model is tools/build_cage.py's.

signal broken

## How many hits it takes.
const HITS := 3
const MODEL := preload("res://models/cage.glb")

var hits := 0
## The hero's dust, for the puff it bursts in (set by whoever makes it).
var dust: CloudDust
var _model: Node3D
var _rattle := 0.0


func _ready() -> void:
	add_to_group(&"tail_hittable")
	_model = MODEL.instantiate()
	add_child(_model)
	Toon.apply(_model)
	var box := BoxShape3D.new()
	box.size = Vector3(1.08, 1.2, 1.08)
	var shape := CollisionShape3D.new()
	shape.shape = box
	shape.position.y = 0.6
	add_child(shape)


## Hit by his tail: it rattles, and breaks on the last hit.
func tail_hit(_from: Vector3, push: Vector3) -> void:
	if hits >= HITS:
		return
	hits += 1
	_rattle = 1.0
	if hits >= HITS:
		_burst(push)


func _process(delta: float) -> void:
	if _model == null or _rattle <= 0.0:
		return
	_rattle = maxf(_rattle - delta * 4.0, 0.0)
	_model.rotation = Vector3(sin(_rattle * 40.0) * 0.06, 0.0, cos(_rattle * 33.0) * 0.06) * _rattle


func _burst(push: Vector3) -> void:
	broken.emit()
	var world_parent := get_parent()
	var away := Vector3(push.x, 0.0, push.z).normalized()
	for part: MeshInstance3D in _model.find_children("*", "MeshInstance3D", true, false):
		# (each part flies off on a body of its own, tumbling, then shrinks away)
		var body := RigidBody3D.new()
		body.collision_layer = 0
		body.collision_mask = 1
		var size := part.get_aabb().size.max(Vector3.ONE * 0.04)
		var box := BoxShape3D.new()
		box.size = size
		var shape := CollisionShape3D.new()
		shape.shape = box
		body.add_child(shape)
		var at := part.global_transform
		world_parent.add_child(body)
		body.global_transform = Transform3D(at.basis.orthonormalized(), at * part.get_aabb().get_center())
		part.get_parent().remove_child(part)
		body.add_child(part)
		part.transform = Transform3D(Basis.IDENTITY, -part.get_aabb().get_center())
		var out := (body.global_position - global_position)
		out.y = 0.0
		body.linear_velocity = (out.normalized() * randf_range(2.0, 4.0) + away * 1.5 + Vector3.UP * randf_range(2.5, 5.0))
		body.angular_velocity = Vector3(randf_range(-8, 8), randf_range(-8, 8), randf_range(-8, 8))
		var fade := body.create_tween()
		fade.tween_interval(1.6)
		fade.tween_property(part, ^"scale", Vector3.ONE * 0.01, 0.5)
		fade.tween_callback(body.queue_free)
	if dust:
		for k in 12:
			var a := TAU * k / 12.0
			var out := Vector3(cos(a), 0.0, sin(a))
			dust.puff(global_position + out * 0.4, out * 1.6 + Vector3.UP * 0.8, 0.18)
	queue_free()
