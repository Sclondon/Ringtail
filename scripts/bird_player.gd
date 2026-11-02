class_name BirdPlayer
extends CharacterBody3D
## Playing as the crow or the owl (the user, 2026-11-02: "and add a mode where you can be the crow or owl"): chosen on
## the pause screen (PauseMenu's "Play as"), in place of the raccoon, who is put away meanwhile and comes back on the
## ground under the bird when he is chosen again (`play_as`). The bird is tools/build_birds.py's model, posed by
## BirdBody; its own camera (BirdCamera) follows it.
##
## On the ground it hops about. Jump takes off, and each press in the air is a flap that lifts it (held, it glides);
## the stick steers, banking into turns; duck dives (the owl swoops faster); scurry makes for the nearest wire or post
## top and settles on it; the tail button pecks (knocks what the raccoon's tail knocks, but not a cage: those are his
## to break). It lands on whatever it comes down on: the ground, a roof, a wire, a pole, a tree. Both pick up Crumbs
## (they count as his); the hunters leave a bird be, and nothing hurts the raccoon while he is put away (World.hurt).
## Kinds' feel (Claude's picks): the crow agile, quick rowing flaps; the owl slow deep flaps, long glides, a fast
## swoop, and its head turns to look where the camera looks.

const KINDS := {
	&"crow": {"radius": 0.16, "walk": 1.5, "cruise": 6.5, "top": 9.5, "turn": 6.0, "flap": 3.6, "flap_every": 0.2,
		"glide_fall": 1.7, "dive": 13.0, "swoop": 1.0, "camera": 3.0},
	&"owl": {"radius": 0.22, "walk": 0.9, "cruise": 5.0, "top": 8.0, "turn": 3.5, "flap": 4.4, "flap_every": 0.45,
		"glide_fall": 0.8, "dive": 17.0, "swoop": 1.5, "camera": 3.6},
}
## How high over where it started it may go.
const CEILING := 40.0

var kind := &"crow"
var world: World
var body: BirdBody
var camera: BirdCamera
## Up in the air (else on the ground, or on whatever it stands on).
var flying := false
## Where it is making for to settle (scurry), or INF.
var settle_on := Vector3.INF
var facing_yaw := 0.0

var _cfg: Dictionary
var _ceiling := INF
var _flap_cool := 0.0
var _flapping := 0.0
var _hop := 0.0
## The HUD's buttons held / pressed (touch and mouse), beside the keys and pad.
var _held := {}
var _tapped := {}
var _turning := 0.0


## Who is played now in `world`: its bird, or null for the raccoon.
static func active(world: Node) -> BirdPlayer:
	return world.get_node_or_null(^"BirdPlayer") as BirdPlayer if world else null


## Plays as `who` (&"raccoon", &"crow", &"owl", or any of AnimalPlayer.ANIMALS) in `world`, from where whoever is
## played now is.
static func play_as(world: World, who: StringName) -> void:
	var bird := active(world)
	if who == &"raccoon":
		if bird:
			_bring_back(world, bird.global_position)
			bird.name = "BirdLeaving"
			bird.queue_free()
		return
	if bird and bird.kind == who:
		return
	var from := bird.global_position if bird else world.player.global_position + Vector3.UP * 0.3
	var yaw := bird.facing_yaw if bird else world.player.facing_yaw
	if bird:
		bird.name = "BirdLeaving"
		bird.queue_free()
	else:
		_put_away(world)
	# (any other animal: AnimalPlayer, on foot)
	var made: BirdPlayer = BirdPlayer.new() if KINDS.has(who) else AnimalPlayer.new()
	made.name = "BirdPlayer"
	made.kind = who
	made.world = world
	made.facing_yaw = yaw
	world.add_child(made)
	made.global_position = from
	made._ceiling = from.y + CEILING


## The raccoon out of the way: still, unseen, nothing to bump into, not hunted.
static func _put_away(world: World) -> void:
	var him := world.player
	him.set_meta(&"layers", Vector2i(him.collision_layer, him.collision_mask))
	him.collision_layer = 0
	him.collision_mask = 0
	him.velocity = Vector3.ZERO
	him.visible = false
	him.process_mode = Node.PROCESS_MODE_DISABLED
	# (his scurry bars would stay frozen on screen if he was put away scurrying)
	for bars in him.find_children("*", "ScurryBars", true, false):
		bars.visible = false
	world.camera.process_mode = Node.PROCESS_MODE_DISABLED


## The raccoon back, on the ground under `at`.
static func _bring_back(world: World, at: Vector3) -> void:
	var him := world.player
	var hit := world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(at + Vector3.UP * 0.5, at + Vector3.DOWN * 60.0, 1))
	him.global_position = (hit.position as Vector3) + Vector3.UP * 0.05 if not hit.is_empty() else at
	him.velocity = Vector3.ZERO
	var layers: Vector2i = him.get_meta(&"layers", Vector2i(2, 1))
	him.collision_layer = layers.x
	him.collision_mask = layers.y
	him.visible = true
	him.process_mode = Node.PROCESS_MODE_INHERIT
	for bars in him.find_children("*", "ScurryBars", true, false):
		bars.visible = true
	world.camera.process_mode = Node.PROCESS_MODE_INHERIT
	world.camera.make_current()
	world.camera.snap()


func _ready() -> void:
	_cfg = KINDS[kind]
	# (as he is: on the second layer, so the Crumbs see it; the world, cars, roofs and wires stop it)
	collision_layer = 2
	collision_mask = 1
	floor_snap_length = 0.1
	var ball := SphereShape3D.new()
	ball.radius = float(_cfg.radius)
	var shape := CollisionShape3D.new()
	shape.shape = ball
	shape.position.y = float(_cfg.radius)
	add_child(shape)
	body = BirdBody.make(kind)
	add_child(body)
	# (the wires make themselves solid for whoever is near them, and hold whoever stands on them)
	add_to_group(&"tightrope_walkers")
	camera = BirdCamera.new()
	camera.bird = self
	camera.distance = float(_cfg.camera)
	world.add_child.call_deferred(camera)
	camera.ready.connect(func() -> void:
		camera.look_along(Vector3(sin(facing_yaw), 0.0, cos(facing_yaw)))
		camera.make_current())
	tree_exiting.connect(func() -> void:
		if is_instance_valid(camera):
			camera.queue_free())


## For the HUD's buttons: an action held down or let go (jump, duck, scurry, tail).
func press(action: StringName, down: bool) -> void:
	_held[action] = down
	if down:
		_tapped[action] = true


func _down(action: StringName) -> bool:
	if Player.input_blocked:
		return false
	var touch: TouchControls = world.player._touch if world and world.player else null
	if touch and ((action == &"jump" and touch.jump_held) or (action == &"duck" and touch.duck_held)):
		return true
	return bool(_held.get(action, false)) or (InputMap.has_action(action) and Input.is_action_pressed(action))


func _just(action: StringName) -> bool:
	if Player.input_blocked:
		return false
	var tapped: bool = _tapped.get(action, false)
	_tapped[action] = false
	return tapped or (InputMap.has_action(action) and Input.is_action_just_pressed(action))


## The stick, as a level direction in the world from the camera's view (its length how far it is pushed).
func _stick() -> Vector3:
	if Player.input_blocked:
		return Vector3.ZERO
	var raw := Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
	var touch: TouchControls = world.player._touch if world and world.player else null
	if touch and touch.move.length_squared() > raw.length_squared():
		raw = touch.move
	var view := camera.global_basis if is_instance_valid(camera) and camera.is_inside_tree() else global_basis
	var ahead := -view.z
	ahead.y = 0.0
	var right := view.x
	right.y = 0.0
	return (right.normalized() * raw.x - ahead.normalized() * raw.y).limit_length(1.0)


func _physics_process(delta: float) -> void:
	var stick := _stick()
	var grounded := is_on_floor()
	_flap_cool -= delta
	_flapping = maxf(_flapping - delta, 0.0)
	if _just(&"jump"):
		if grounded:
			velocity.y = float(_cfg.flap) * 1.25
			flying = true
			_flapping = 0.4
			_flap_cool = float(_cfg.flap_every)
		elif _flap_cool <= 0.0:
			velocity.y = maxf(velocity.y, 0.0) + float(_cfg.flap)
			_flapping = 0.35
			_flap_cool = float(_cfg.flap_every)
	if _just(&"scurry"):
		_seek_perch()
	if _just(&"tail"):
		_peck()
	var flat := Vector3(velocity.x, 0.0, velocity.z)
	if grounded and velocity.y <= 0.01:
		flying = false
		settle_on = Vector3.INF
		# Hopping about: little hops along the stick
		var want := stick * float(_cfg.walk)
		flat = flat.move_toward(want, 12.0 * delta)
		_hop -= delta
		velocity.y = -0.5
		if want.length() > 0.2 and _hop <= 0.0:
			velocity.y = 2.0
			_hop = 0.32
	else:
		flying = true
		# (making for a perch: straight in, no falling short of it)
		if settle_on != Vector3.INF:
			_glide_in(delta)
			return
		var gliding := _down(&"jump") and velocity.y < 0.0
		var diving := _down(&"duck")
		var gravity := 9.8 * (0.5 if gliding else 1.0)
		velocity.y -= gravity * delta
		if gliding:
			velocity.y = maxf(velocity.y, -float(_cfg.glide_fall))
		# (steered by the stick, at cruising speed or more as it is pushed; left alone it keeps on, slowing a little)
		var want := stick.normalized() * lerpf(float(_cfg.cruise), float(_cfg.top), stick.length()) if stick.length() > 0.1 \
				else flat * 0.98
		var turned_from := flat
		flat = flat.move_toward(want, float(_cfg.turn) * delta * maxf(flat.length(), 2.0) * 0.5)
		_turning = lerpf(_turning, turned_from.signed_angle_to(flat, Vector3.UP) / maxf(delta, 0.001), 1.0 - exp(-6.0 * delta))
		if diving:
			# (a dive: down hard, gathering speed; the owl swoops faster)
			velocity.y = move_toward(velocity.y, -float(_cfg.dive), 26.0 * delta)
			flat = flat.limit_length(float(_cfg.top) * float(_cfg.swoop) + 2.0)
			if flat.length() < float(_cfg.cruise) * float(_cfg.swoop):
				flat += (flat.normalized() if flat.length() > 0.1 else Vector3(sin(facing_yaw), 0.0, cos(facing_yaw))) * 10.0 * delta
	velocity = Vector3(flat.x, velocity.y, flat.z)
	if global_position.y > _ceiling:
		velocity.y = minf(velocity.y, 0.0)
	move_and_slide()
	if global_position.y < World.KILL_Y:
		# (fallen off the world: back where he was put away, a little over it)
		global_position = world.player.global_position + Vector3.UP * 2.0
		velocity = Vector3.ZERO
	_face(delta)
	_pose(delta)


## Making for the place it chose to settle: straight there, slowing, and set down on it.
func _glide_in(delta: float) -> void:
	var to := settle_on - global_position
	if to.length() < 0.2:
		global_position = settle_on
		velocity = Vector3.ZERO
		settle_on = Vector3.INF
		flying = false
		_pose(delta)
		return
	velocity = velocity.lerp(to.normalized() * clampf(to.length() * 3.0, 1.5, 7.0), 1.0 - exp(-5.0 * delta))
	global_position += velocity * delta
	_face(delta)
	_pose(delta)


## The nearest wire or post top within reach to settle on (a pole's top, a tree's tip, a point on a wire), if any.
func _seek_perch() -> void:
	var best := Vector3.INF
	var nearest := 5.0
	for node in get_tree().get_nodes_in_group(&"tightropes"):
		var wire := node as Tightrope
		if wire == null:
			continue
		var on := wire.point_near(global_position)
		var d := on.distance_to(global_position)
		if d < nearest:
			nearest = d
			best = on + Vector3.UP * 0.02
	# (the tops of poles and trees: PointPerches, where there are any)
	if ResourceLoader.exists("res://scripts/point_perches.gd"):
		var points: GDScript = load("res://scripts/point_perches.gd")
		var top: Vector3 = points.nearest(global_position, nearest)
		if top != Vector3.INF and top.distance_to(global_position) < nearest:
			best = top
	if best != Vector3.INF:
		settle_on = best


## A peck: what is close in front of it is knocked, as his tail knocks it (not a cage).
func _peck() -> void:
	body.peck()
	var ahead := Vector3(sin(facing_yaw), 0.0, cos(facing_yaw))
	var from := global_position + Vector3.UP * 0.15
	for node in get_tree().get_nodes_in_group(&"tail_hittable"):
		if not node is Node3D or node is Cage:
			continue
		var to: Vector3 = (node as Node3D).global_position - from
		if to.length() > 0.9 or ahead.dot(Vector3(to.x, 0.0, to.z).normalized()) < 0.2:
			continue
		var push := ahead * 3.0 + Vector3.UP * 1.5
		if node.has_method(&"tail_hit"):
			node.tail_hit(from, push)
		elif node is RigidBody3D:
			(node as RigidBody3D).apply_central_impulse(push * (node as RigidBody3D).mass)


func _face(delta: float) -> void:
	var flat := Vector3(velocity.x, 0.0, velocity.z)
	if flat.length() > 0.3:
		facing_yaw = lerp_angle(facing_yaw, atan2(flat.x, flat.z), 1.0 - exp(-10.0 * delta))
	rotation.y = facing_yaw


## Wings, legs, lean and bank, from what it is doing.
func _pose(delta: float) -> void:
	var rising := velocity.y > 0.5
	body.fold = 0.0 if flying else 1.0
	body.tuck = 1.0 if flying else 0.0
	body.flap = 1.0 if _flapping > 0.0 or (flying and rising) else (0.0 if flying else 0.0)
	body.flare = 0.0
	if flying and velocity.y < 0.0:
		# (coming down near the ground: wings thrown forward, feet out)
		var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(global_position, global_position + Vector3.DOWN * 0.9, 1))
		if not hit.is_empty():
			body.flare = 1.0
			body.tuck = 0.0
	# (banked into a turn, nose down diving, level gliding)
	var bank := clampf(-_turning * 0.25, -0.8, 0.8) if flying else 0.0
	var pitch := clampf(-velocity.y * 0.05, -0.6, 0.7) if flying else 0.0
	body.rotation.z = lerp_angle(body.rotation.z, bank, 1.0 - exp(-6.0 * delta))
	body.rotation.x = lerp_angle(body.rotation.x, pitch, 1.0 - exp(-6.0 * delta))
	# (the owl's head turns to look where the camera looks; on the ground, both look about where it looks)
	if is_instance_valid(camera) and camera.is_inside_tree() and (kind == &"owl" or not flying):
		body.look_at_point(camera.global_position - camera.global_basis.z * 30.0)
	else:
		body.look_at_point(Vector3.INF)
