class_name YardCat
extends CharacterBody3D
## A yard cat (the enemy; each its own look, FurLook.CAT_LOOKS: placeholders), built and animated as the raccoon is: his model
## kit and his rig (CatRig, a RaccoonRig, on all fours whenever it is on the ground). It wanders its patch;
## when the raccoon comes near it stalks him low, stops, wiggles its rump, and pounces in a leap. A pounce
## that reaches him hurts him. His tail spin (`tail_hit`) knocks it tumbling, and it runs off for good, with
## a "beaten" signal.
##
## The rig takes this body as it would a Player: `velocity`, `is_on_floor()`, the speeds, `is_ducking` (low,
## stalking), and `jumped` and `landed` for its leap.

signal beaten(cat: YardCat)
# (for the rig: the leap off the ground, and coming down)
signal jumped
signal landed(impact_speed: float)
signal respawned

enum Mode { WANDER, STALK, CROUCH, POUNCE, RECOVER, DAZED, FLEE }

@export var notice := 6.0
@export var pounce_from := 2.6
@export var wander_radius := 3.5
@export var pounce_speed := 6.0
## How big it is beside him (the raccoon's skeleton, made smaller).
@export var size := 0.85

# (slower than the raccoon, so he can get away from it and round it)
var walk_speed := 0.9
var run_speed := 3.6
var is_pushing := false
var is_ducking := false
var is_crawling := false

var mode := Mode.WANDER
var target: Player
var home := Vector3.ZERO
var rig: CatRig
## Which cat of the town it is (in the order made): its look is FurLook.cat(index).
var index := 0
static var _made := 0

var _t := 0.0
var _mode_t := 0.0
var _goal := Vector3.ZERO
var _hurt_done := false
var _gravity := 20.0
var _was_on_floor := true


## A cat ready to be placed (set `position` and `target`) and added.
static func make() -> YardCat:
	return YardCat.new()


func _ready() -> void:
	add_to_group(&"tail_hittable")
	add_to_group(&"cats")
	# (layer 4, not the player's 2: pickups, the trampoline and the wires only look for him)
	collision_layer = 4
	collision_mask = 1
	var shape := CapsuleShape3D.new()
	shape.radius = 0.19
	shape.height = 0.7
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.rotation.x = PI / 2
	collider.position.y = 0.26
	add_child(collider)
	rig = CatRig.new()
	rig.name = "Rig"
	# (each cat its own look: colours, fur type, markings; the user, 2026-11-02, "the cats need color variations ...
	# different fur types")
	index = _made
	_made += 1
	var look := FurLook.cat(index)
	rig.model = load(FurLook.model_path("cat", look.get("fur", "spiky")))
	rig.look = look
	rig.scale = Vector3.ONE * size
	rig.dusty = false
	add_child(rig)
	home = global_position
	_goal = home


func _physics_process(delta: float) -> void:
	_t += delta
	_mode_t += delta
	var grounded := is_on_floor()
	if not grounded:
		velocity.y -= _gravity * delta
	var to_target := Vector3.ZERO
	var near := INF
	if target:
		to_target = target.global_position - global_position
		near = Vector2(to_target.x, to_target.z).length()
	var sees := near < notice and absf(to_target.y) < 1.5 and not Hazards.safe(target.global_position)
	is_ducking = false
	rig.wiggle = 0.0
	match mode:
		Mode.WANDER:
			if global_position.distance_to(_goal) < 0.4 or _mode_t > 4.0:
				_goal = home + Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0)) * wander_radius
				_mode_t = 0.0
			_walk_to(_goal, walk_speed, delta)
			if sees and grounded:
				_go(Mode.STALK)
		Mode.STALK:
			# Low, creeping straight at him
			is_ducking = true
			_walk_to(target.global_position, walk_speed * 1.2, delta)
			if not sees:
				_go(Mode.WANDER)
			elif near < pounce_from and grounded:
				_go(Mode.CROUCH)
		Mode.CROUCH:
			is_ducking = true
			_walk_to(global_position, 0.0, delta)
			_face(to_target, delta * 8.0)
			rig.wiggle = smoothstep(0.1, 0.5, _mode_t)
			if _mode_t > 0.85:
				var flat := Vector3(to_target.x, 0.0, to_target.z)
				var speed := clampf(flat.length() / 0.55, 2.0, pounce_speed)
				velocity = flat.normalized() * speed + Vector3.UP * 5.0
				_hurt_done = false
				_go(Mode.POUNCE)
				jumped.emit()
		Mode.POUNCE:
			if not _hurt_done and target and global_position.distance_to(target.global_position + Vector3.UP * 0.3) < 0.75:
				_hurt_done = true
				var game := get_tree().get_first_node_in_group(&"game")
				if game:
					game.hurt(global_position)
			if grounded and _mode_t > 0.2:
				velocity = Vector3.ZERO
				_go(Mode.RECOVER)
		Mode.RECOVER:
			_walk_to(global_position, 0.0, delta)
			_face(to_target, delta * 4.0)
			if _mode_t > 0.7:
				_go(Mode.STALK if sees else Mode.WANDER)
		Mode.DAZED:
			# Tumbling end over end through the air; down, it rights itself, shakes it off, and runs
			if grounded and _mode_t > 0.2:
				velocity.x = move_toward(velocity.x, 0.0, 10.0 * delta)
				velocity.z = move_toward(velocity.z, 0.0, 10.0 * delta)
				rig.tumble = lerp_angle(rig.tumble, 0.0, 1.0 - exp(-10.0 * delta))
			else:
				rig.tumble = fposmod(rig.tumble + delta * 13.0, TAU)
			if _mode_t > 1.1:
				rig.tumble = 0.0
				_go(Mode.FLEE)
		Mode.FLEE:
			var away := -Vector3(to_target.x, 0.0, to_target.z).normalized() if target else Vector3.FORWARD
			_walk_to(global_position + away, run_speed, delta)
			rig.scale = Vector3.ONE * size * maxf(0.01, 1.0 - (_mode_t - 1.2))
			if _mode_t > 2.2:
				queue_free()
	var falling := velocity.y
	move_and_slide()
	if is_on_floor() and not _was_on_floor:
		landed.emit(absf(falling))
	_was_on_floor = is_on_floor()


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


## Hit by his tail: knocked tumbling, then off it runs.
func tail_hit(_from: Vector3, push: Vector3) -> void:
	if mode == Mode.DAZED or mode == Mode.FLEE:
		return
	velocity = push * 1.1
	_go(Mode.DAZED)
	beaten.emit(self)
