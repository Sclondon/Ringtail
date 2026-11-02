class_name HazardBird
extends Node3D
## A crow or a hawk (models/crow.glb: tools/build_birds.py, posed by BirdBody; hawk.glb: tools/build_hazards.py,
## its wings beaten by turning them at the shoulder), flown by code. Claude's picks for how they behave (placeholders):
##
## - HAWK: circles high over its `home`. When the raccoon comes under it, it circles in over him and its shadow on the
##   ground darkens and grows (the warning, STALK), then it folds and dives at where he is going; caught, he is hurt.
##   It pulls up, climbs back and leaves him be a while.
## - CROW: one of a band (HazardCrows), hopping about on the ground; the band sends one at a time to dive-bomb him when
##   he is near, swooping at his head and landing again.
## Hit by his tail it tumbles away, flies off, and comes back later. Hurts through Hazards.hurt (World.hurt).

signal knocked

enum Kind { CROW, HAWK }
enum State { GROUND, FLY, STALK, DIVE, CLIMB, KNOCKED, AWAY }

const MODELS := {Kind.CROW: "res://models/crow.glb", Kind.HAWK: "res://models/hawk.glb"}

var kind := Kind.CROW
var home := Vector3.ZERO
var player: Player
var state := State.FLY

## Hawk: how high and how wide it circles, how near he must come under it, how long the warning, how fast the dive.
var circle_height := 13.0
var circle_radius := 8.0
var notice := 16.0
var warning := 2.2
var dive_speed := 15.0
var rest := 6.0

var velocity := Vector3.ZERO
var _model: Node3D
var _bird: BirdBody
var _wings: Array[Node3D] = []
var _shadow: MeshInstance3D
var _shadow_look: StandardMaterial3D
var _t := 0.0
var _state_t := 0.0
var _angle := randf() * TAU
var _target := Vector3.ZERO
var _hit_done := false
var _rest_left := 2.0
var _flap := 0.0
var _flap_speed := 0.0
var _spin := 0.0


func _ready() -> void:
	add_to_group(&"tail_hittable")
	add_to_group(&"hazards")
	if kind == Kind.CROW:
		# (the crow is tools/build_birds.py's, posed by BirdBody: wings that fold, a head that looks and pecks)
		_bird = BirdBody.make(&"crow")
		_model = _bird
		add_child(_model)
	else:
		_model = (load(MODELS[kind]) as PackedScene).instantiate()
		add_child(_model)
		Toon.apply(_model)
		for node: Node in _model.find_children("*", "Node3D", true, false):
			if String(node.name).ends_with("_wing_l") or String(node.name).ends_with("_wing_r"):
				_wings.append(node)
	_shadow = MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 0.5
	disc.bottom_radius = 0.5
	disc.height = 0.01
	disc.radial_segments = 16
	_shadow.mesh = disc
	_shadow_look = StandardMaterial3D.new()
	_shadow_look.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_shadow_look.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_shadow_look.albedo_color = Color(0.0, 0.0, 0.0, 0.0)
	_shadow.material_override = _shadow_look
	_shadow.top_level = true
	_shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_shadow)
	if kind == Kind.HAWK:
		global_position = home + Vector3(circle_radius, circle_height, 0.0)
		state = State.FLY
	else:
		global_position = home
		state = State.GROUND


func _go(to: State) -> void:
	state = to
	_state_t = 0.0


func _physics_process(delta: float) -> void:
	_t += delta
	_state_t += delta
	_rest_left = maxf(_rest_left - delta, 0.0)
	if kind == Kind.HAWK:
		_hawk(delta)
	else:
		_crow(delta)
	_pose(delta)
	_place_shadow()


## Where he is, a little above his feet (where a beak or talons aim).
func _him() -> Vector3:
	return player.global_position + Vector3.UP * 0.45 if player else home


func _hawk(delta: float) -> void:
	var under := player != null and Vector2(player.global_position.x - home.x, player.global_position.z - home.z).length() < notice and not Hazards.unseen(player)
	match state:
		State.FLY:
			_angle += delta * 0.45
			var aim := home + Vector3(cos(_angle) * circle_radius, circle_height + sin(_t * 0.7) * 0.6, sin(_angle) * circle_radius)
			_steer(aim, 7.0, delta)
			if under and _rest_left <= 0.0 and player.is_on_floor():
				_go(State.STALK)
		State.STALK:
			# Circling in tight over him, lower: the shadow darkens on the ground round him
			_angle += delta * 1.4
			var over := player.global_position + Vector3(cos(_angle) * 3.0, 8.0, sin(_angle) * 3.0)
			_steer(over, 10.0, delta)
			if not under:
				_go(State.CLIMB)
			elif _state_t > warning:
				_target = _him() + Vector3(player.velocity.x, 0.0, player.velocity.z) * 0.35
				_hit_done = false
				_go(State.DIVE)
		State.DIVE:
			var to := _target - global_position
			velocity = velocity.lerp(to.normalized() * dive_speed, 1.0 - exp(-8.0 * delta))
			global_position += velocity * delta
			_catch(0.85)
			if to.length() < 0.6 or global_position.y < _target.y - 0.2 or _state_t > 3.0:
				_go(State.CLIMB)
		State.CLIMB:
			var up := Vector3(global_position.x, home.y + circle_height, global_position.z) + Vector3(velocity.x, 0.0, velocity.z).normalized() * 6.0
			_steer(up, 8.0, delta)
			if global_position.y > home.y + circle_height - 1.0 or _state_t > 5.0:
				_rest_left = rest
				_go(State.FLY)
		State.KNOCKED:
			_tumble(delta)
			if _state_t > 1.0:
				_go(State.AWAY)
		State.AWAY:
			_steer(home + Vector3(0.0, circle_height + 4.0, 0.0), 9.0, delta)
			if _state_t > 3.0:
				_rest_left = rest * 1.5
				_go(State.FLY)


func _crow(delta: float) -> void:
	match state:
		State.GROUND:
			# Hopping about its spot, now and then
			velocity.x = move_toward(velocity.x, 0.0, 6.0 * delta)
			velocity.z = move_toward(velocity.z, 0.0, 6.0 * delta)
			var floor_y := _ground_below(global_position)
			if global_position.y <= floor_y + 0.001 and velocity.y <= 0.0:
				global_position.y = floor_y
				velocity.y = 0.0
				if randf() < delta * 0.8:
					var a := randf() * TAU
					var hop := Vector3(cos(a), 0.0, sin(a)) * 0.9
					if global_position.distance_to(home) > 2.5:
						hop = (home - global_position).normalized() * 0.9
					velocity = Vector3(hop.x, 2.4, hop.z)
			else:
				velocity.y -= 12.0 * delta
			global_position += velocity * delta
			if player:
				_face(player.global_position, delta * 3.0)
		State.DIVE:
			# Up and over in an arc, then down at his head, and on past
			var to := _target - global_position
			var rise := Vector3.UP * 3.0 * (1.0 - smoothstep(0.0, 0.5, _state_t))
			velocity = velocity.lerp(to.normalized() * 9.0 + rise, 1.0 - exp(-5.0 * delta))
			global_position += velocity * delta
			_catch(0.6)
			if to.length() < 0.5 or _state_t > 2.5:
				_target = home + Vector3(randf_range(-2.0, 2.0), 0.0, randf_range(-2.0, 2.0))
				_go(State.FLY)
		State.FLY:
			_steer(_target + Vector3.UP * 0.1, 6.0, delta)
			if global_position.distance_to(_target) < 0.5 or _state_t > 4.0:
				global_position = _target
				velocity = Vector3.ZERO
				_go(State.GROUND)
		State.KNOCKED:
			_tumble(delta)
			if _state_t > 0.9:
				_target = home + Vector3(0.0, 9.0, 0.0) + Vector3(randf_range(-6, 6), 0.0, randf_range(-6, 6))
				_go(State.AWAY)
		State.AWAY:
			_steer(_target, 7.0, delta)
			if _state_t > 6.0:
				_target = home + Vector3(randf_range(-2.0, 2.0), 0.0, randf_range(-2.0, 2.0))
				_go(State.FLY)


## For HazardCrows: dive at him now (a crow on the ground).
func dive() -> bool:
	if state != State.GROUND or player == null:
		return false
	_target = _him() + Vector3(player.velocity.x, 0.0, player.velocity.z) * 0.3
	_hit_done = false
	velocity = Vector3(0.0, 3.0, 0.0)
	_go(State.DIVE)
	return true


func _steer(to: Vector3, speed: float, delta: float) -> void:
	var want := (to - global_position).limit_length(speed)
	velocity = velocity.lerp(want, 1.0 - exp(-2.5 * delta))
	global_position += velocity * delta


func _catch(reach: float) -> void:
	if _hit_done or player == null:
		return
	if global_position.distance_to(_him()) < reach:
		_hit_done = true
		Hazards.hurt(self, global_position)


func _tumble(delta: float) -> void:
	velocity.y -= 6.0 * delta
	global_position += velocity * delta
	_spin += delta * 14.0


func _face(point: Vector3, rate: float) -> void:
	var to := point - global_position
	if Vector2(to.x, to.z).length() > 0.05:
		rotation.y = lerp_angle(rotation.y, atan2(to.x, to.z), clampf(rate, 0.0, 1.0))


## Hit by his tail: knocked tumbling away.
func tail_hit(_from: Vector3, push: Vector3) -> void:
	if state == State.KNOCKED or state == State.AWAY:
		return
	velocity = push * (1.4 if kind == Kind.CROW else 0.9) + Vector3.UP * 3.0
	_hit_done = true
	_go(State.KNOCKED)
	knocked.emit()


func _pose(delta: float) -> void:
	# Facing the way it flies (level), banking into turns; wings beating, gliding, folded or tucked for a dive
	var flat := Vector3(velocity.x, 0.0, velocity.z)
	if state != State.GROUND and state != State.KNOCKED and flat.length() > 0.3:
		var yaw := atan2(flat.x, flat.z)
		var turn := angle_difference(rotation.y, yaw)
		rotation.y = lerp_angle(rotation.y, yaw, 1.0 - exp(-6.0 * delta))
		rotation.z = lerp_angle(rotation.z, -clampf(turn * 2.0, -0.7, 0.7), 1.0 - exp(-4.0 * delta))
		rotation.x = lerp_angle(rotation.x, clampf(-velocity.y * 0.06, -0.9, 0.6), 1.0 - exp(-5.0 * delta))
	else:
		rotation.z = lerp_angle(rotation.z, 0.0, 1.0 - exp(-6.0 * delta))
		rotation.x = lerp_angle(rotation.x, 0.0, 1.0 - exp(-6.0 * delta))
	_model.rotation = Vector3(_spin, 0.0, _spin * 0.6) if state == State.KNOCKED else Vector3.ZERO
	if state != State.KNOCKED:
		_spin = 0.0
	if _bird:
		_pose_bird()
		return
	var beat := 0.0
	var fold := 0.0
	match state:
		State.GROUND:
			fold = 1.0
			beat = 0.0 if velocity.y <= 0.0 else 0.8
		State.DIVE:
			fold = 0.55 if kind == Kind.HAWK else 0.0
			beat = 0.0 if kind == Kind.HAWK else 1.0
		State.FLY, State.AWAY, State.CLIMB:
			# (the hawk mostly soars, beating now and then)
			beat = 1.0 if kind == Kind.CROW or state == State.CLIMB or sin(_t * 0.6) > 0.6 else 0.15
		State.STALK:
			beat = 0.2
		State.KNOCKED:
			beat = 1.0
	_flap_speed = lerpf(_flap_speed, beat, 1.0 - exp(-6.0 * delta))
	_flap += delta * (13.0 if kind == Kind.CROW else 7.0) * _flap_speed
	var angle := sin(_flap) * 0.85 * _flap_speed
	for wing in _wings:
		var side := 1.0 if String(wing.name).ends_with("_l") else -1.0
		# (beating: up and down about the shoulder; folded: swept back along the body and down)
		wing.rotation = Vector3(0.0, side * fold * 1.25, side * (angle * (1.0 - fold) - fold * 0.5))


## The crow (BirdBody): on the ground folded, eyeing him, pecking now and then, a flick of the wings as it hops;
## flying, beating hard, gliding in to land; diving at him half folded; knocked, flailing.
func _pose_bird() -> void:
	var flying := state != State.GROUND
	_bird.tuck = 1.0 if flying and state != State.KNOCKED else 0.0
	_bird.flare = 0.0
	match state:
		State.GROUND:
			var hopping := velocity.y > 0.0
			_bird.fold = 0.55 if hopping else 1.0
			_bird.flap = 1.0 if hopping else 0.0
			if not hopping and randf() < get_physics_process_delta_time() * 0.5:
				_bird.peck()
		State.DIVE:
			_bird.fold = 0.45
			_bird.flap = 0.2
		State.FLY:
			# (coming in to land: wings out, gliding, then thrown forward braking, feet out)
			var near := global_position.distance_to(_target)
			_bird.fold = 0.0
			_bird.flap = 0.15 if near < 1.6 else 1.0
			_bird.flare = 1.0 if near < 0.7 else 0.0
			_bird.tuck = 0.0 if near < 0.7 else 1.0
		State.KNOCKED:
			_bird.fold = 0.1
			_bird.flap = 1.0
		_:
			_bird.fold = 0.0
			_bird.flap = 1.0
	_bird.look_at_point(_him() if player and state != State.KNOCKED else Vector3.INF)


func _place_shadow() -> void:
	var ground := _ground_below(global_position)
	var height := global_position.y - ground
	var size := (0.35 if kind == Kind.CROW else 0.9) * (1.0 + height * 0.04)
	var dark := 0.35 if kind == Kind.CROW else 0.2
	if kind == Kind.HAWK:
		# (the warning: as it circles in over him, its shadow grows darker and bigger; diving, darkest)
		match state:
			State.STALK:
				dark = 0.2 + 0.4 * smoothstep(0.0, warning, _state_t)
				size *= 1.0 + 0.8 * smoothstep(0.0, warning, _state_t)
			State.DIVE:
				dark = 0.65
	_shadow.global_position = Vector3(global_position.x, ground + 0.03, global_position.z)
	_shadow.scale = Vector3(size, 1.0, size)
	_shadow_look.albedo_color = Color(0.0, 0.0, 0.0, dark * (1.0 - smoothstep(18.0, 30.0, height)))


func _ground_below(at: Vector3) -> float:
	var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(at + Vector3.UP * 0.5, at + Vector3.DOWN * 60.0, 1))
	return (hit.position as Vector3).y if not hit.is_empty() else home.y
