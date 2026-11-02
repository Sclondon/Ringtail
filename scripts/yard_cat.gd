class_name YardCat
extends CharacterBody3D
## A ginger yard cat (the placeholder enemy). It wanders its patch of lawn; when the
## raccoon comes near it crouches, wiggles its rump, and pounces at him. A pounce that
## lands on him hurts him. A tail whip or spin (`tail_hit`) knocks it flying and
## it runs off for good, with a "beaten" signal.

signal beaten(cat: YardCat)

enum Mode { WANDER, CROUCH, POUNCE, DAZED, FLEE }

@export var notice := 6.0
@export var wander_radius := 3.5
@export var pounce_speed := 6.5

var mode := Mode.WANDER
var target: Player
var home := Vector3.ZERO

var _model: Node3D
var _t := 0.0
var _mode_t := 0.0
var _goal := Vector3.ZERO
var _hurt_done := false
var _gravity := 20.0


func _ready() -> void:
	add_to_group(&"tail_hittable")
	add_to_group(&"cats")
	collision_layer = 4
	collision_mask = 1
	var shape := CapsuleShape3D.new()
	shape.radius = 0.2
	shape.height = 0.5
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.rotation.x = PI / 2
	collider.position.y = 0.25
	add_child(collider)
	_model = (load("res://models/cat.glb") as PackedScene).instantiate()
	add_child(_model)
	Toon.apply(_model)
	home = global_position
	_goal = home


func _physics_process(delta: float) -> void:
	_t += delta
	_mode_t += delta
	if not is_on_floor():
		velocity.y -= _gravity * delta
	var to_target := Vector3.ZERO
	var near := INF
	if target:
		to_target = target.global_position - global_position
		near = Vector2(to_target.x, to_target.z).length()
	match mode:
		Mode.WANDER:
			if global_position.distance_to(_goal) < 0.4 or _mode_t > 4.0:
				_goal = home + Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0)) * wander_radius
				_mode_t = 0.0
			_walk_to(_goal, 1.0, delta)
			if near < notice and absf(to_target.y) < 1.5 and is_on_floor():
				_go(Mode.CROUCH)
		Mode.CROUCH:
			_walk_to(global_position, 0.0, delta)
			_face(to_target, delta * 8.0)
			if _mode_t > 0.9:
				var flat := Vector3(to_target.x, 0.0, to_target.z)
				var speed := clampf(flat.length() / 0.55, 2.0, pounce_speed)
				velocity = flat.normalized() * speed + Vector3.UP * 5.0
				_hurt_done = false
				_go(Mode.POUNCE)
		Mode.POUNCE:
			if not _hurt_done and target and global_position.distance_to(target.global_position + Vector3.UP * 0.3) < 0.7:
				_hurt_done = true
				var game := get_tree().get_first_node_in_group(&"game")
				if game:
					game.hurt(global_position)
			if is_on_floor() and _mode_t > 0.2:
				velocity = Vector3.ZERO
				_go(Mode.WANDER if near > notice else Mode.CROUCH)
				_mode_t = -0.6 if mode == Mode.CROUCH else 0.0
		Mode.DAZED:
			if is_on_floor() and _mode_t > 0.3:
				velocity.x = move_toward(velocity.x, 0.0, 10.0 * delta)
				velocity.z = move_toward(velocity.z, 0.0, 10.0 * delta)
			if _mode_t > 1.0:
				_go(Mode.FLEE)
		Mode.FLEE:
			var away := -Vector3(to_target.x, 0.0, to_target.z).normalized() if target else Vector3.FORWARD
			_walk_to(global_position + away, 5.0, delta)
			_model.scale = Vector3.ONE * maxf(0.0, 1.0 - (_mode_t - 1.0))
			if _mode_t > 2.0:
				queue_free()
	move_and_slide()
	_pose()


func _go(to: Mode) -> void:
	mode = to
	_mode_t = 0.0


func _walk_to(point: Vector3, speed: float, delta: float) -> void:
	var flat := Vector3(point.x - global_position.x, 0.0, point.z - global_position.z)
	var want := flat.normalized() * speed if flat.length() > 0.1 else Vector3.ZERO
	velocity.x = move_toward(velocity.x, want.x, 12.0 * delta)
	velocity.z = move_toward(velocity.z, want.z, 12.0 * delta)
	if want.length() > 0.1:
		_face(want, delta * 6.0)


func _face(direction: Vector3, rate: float) -> void:
	if Vector2(direction.x, direction.z).length() < 0.01:
		return
	rotation.y = lerp_angle(rotation.y, atan2(direction.x, direction.z), clampf(rate, 0.0, 1.0))


func _pose() -> void:
	# The whole model is moved: a trot bob, the crouched wiggle, stretched out in a pounce, tumbling when hit.
	var speed := Vector2(velocity.x, velocity.z).length()
	_model.position = Vector3.ZERO
	_model.rotation = Vector3.ZERO
	if mode != Mode.FLEE:
		_model.scale = Vector3.ONE
	match mode:
		Mode.WANDER, Mode.FLEE:
			_model.position.y = absf(sin(_t * 9.0)) * 0.04 * minf(speed, 1.0)
		Mode.CROUCH:
			_model.scale = Vector3(1.05, 0.8, 1.05)
			_model.rotation.z = sin(_t * 22.0) * 0.08 * smoothstep(0.2, 0.6, _mode_t)
		Mode.POUNCE:
			_model.scale = Vector3(0.9, 0.9, 1.25)
			_model.rotation.x = -clampf(velocity.y * 0.08, -0.5, 0.5)
		Mode.DAZED:
			_model.rotation.z = _mode_t * 14.0 if not is_on_floor() else PI * 0.5


## Hit by his tail: knocked flying, then off it runs.
func tail_hit(_from: Vector3, push: Vector3) -> void:
	if mode == Mode.DAZED or mode == Mode.FLEE:
		return
	velocity = push * 1.1
	_go(Mode.DAZED)
	beaten.emit(self)
