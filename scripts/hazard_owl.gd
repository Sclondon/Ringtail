class_name HazardOwl
extends Node3D
## An owl (models/owl.glb: tools/build_birds.py, posed by BirdBody; the user, 2026-11-02: "we need to work on a nice
## owl and crow model as well"). Its role is Claude's pick (a placeholder): a predator that sits on a high perch,
## its head turning to follow the raccoon; when he comes near on the ground it stares (eyes wide, no blinking: the
## warning), then drops off its perch and swoops at him silently, gliding, talons thrown forward at the end; caught,
## he is hurt. It beats back up to its perch, deep slow strokes, and glides in to land. Never in the grove
## (Hazards.safe). Hit by his tail it tumbles away and comes back later.
##
##   HazardOwl.place(world, markers, player)      # in World._ready, after Hazards.place
##
## Perches: markers `owl_<n>` if the world has them, otherwise the tops of the poles furthest from the grove (over the
## wires' ends: the first thing below, looking down the pole from above it).

enum State { PERCH, STARE, SWOOP, CLIMB, LAND, KNOCKED, AWAY }

## How many owls, if they perch on poles (Claude's pick).
const ON_POLES := 2

var perch := Vector3.ZERO
var player: Player
var state := State.PERCH
## How near (along the ground) he must come, how long it stares first, how fast it swoops, how long it leaves him be.
var notice := 9.0
var stare := 1.3
var swoop_speed := 11.0
var rest := 7.0

var velocity := Vector3.ZERO
var bird: BirdBody
var _state_t := 0.0
var _rest_left := 3.0
var _target := Vector3.ZERO
var _hit_done := false
var _spin := 0.0
## Whether the perch is still to be found: the top of what is under it (a pole's top, over a wire's end on it).
var _settle := false


static func place(world: Node3D, markers: Dictionary, hero: Player) -> void:
	var perches: Array[Vector3] = []
	for name: String in markers:
		if name.begins_with("owl_"):
			perches.append((markers[name] as Transform3D).origin)
	var on_poles := perches.is_empty()
	if on_poles:
		var tops: Array[Vector3] = []
		for name: String in markers:
			if name.begins_with("wire_") and (name.ends_with("_a") or name.ends_with("_b")):
				var at := (markers[name] as Transform3D).origin
				if not Hazards.safe(at):
					tops.append(at)
		# (the furthest from the grove first, and not two on the same pole)
		tops.sort_custom(func(a: Vector3, b: Vector3) -> bool:
			return Vector2(a.x - Hazards.haven.x, a.z - Hazards.haven.z).length() > Vector2(b.x - Hazards.haven.x, b.z - Hazards.haven.z).length())
		for at in tops:
			if perches.size() >= ON_POLES:
				break
			if perches.all(func(p: Vector3) -> bool: return p.distance_to(at) > 12.0):
				perches.append(at)
	for k in perches.size():
		var owl := HazardOwl.new()
		owl.name = "Owl%d" % k
		owl.perch = perches[k]
		owl._settle = on_poles
		owl.player = hero
		world.add_child(owl)


func _ready() -> void:
	add_to_group(&"tail_hittable")
	add_to_group(&"hazards")
	bird = BirdBody.make(&"owl")
	add_child(bird)
	global_position = perch
	_rest_left = randf_range(2.0, 5.0)


func _go(to: State) -> void:
	state = to
	_state_t = 0.0


func _him() -> Vector3:
	return player.global_position + Vector3.UP * 0.4 if player else perch


func _physics_process(delta: float) -> void:
	if _settle:
		_settle = false
		var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(perch + Vector3.UP * 3.0, perch, 1))
		if not hit.is_empty():
			perch = hit.position
			global_position = perch
	_state_t += delta
	_rest_left = maxf(_rest_left - delta, 0.0)
	var near := player != null and Vector2(player.global_position.x - perch.x, player.global_position.z - perch.z).length() < notice \
			and player.is_on_floor() and not Hazards.unseen(player) \
			and (DayNight.current == null or DayNight.is_night())  # (it hunts by night, and by day roosts: DayNight)
	match state:
		State.PERCH:
			global_position = perch
			velocity = Vector3.ZERO
			if player:
				_face(player.global_position, 1.0 - exp(-1.5 * delta))
			if near and _rest_left <= 0.0:
				_go(State.STARE)
		State.STARE:
			global_position = perch
			if not near:
				_go(State.PERCH)
			elif _state_t > stare:
				_target = _him() + Vector3(player.velocity.x, 0.0, player.velocity.z) * 0.4
				_hit_done = false
				velocity = (_target - global_position).normalized() * 2.0 + Vector3.UP * 1.0
				_go(State.SWOOP)
		State.SWOOP:
			# Down off the perch in a long gliding curve at him, a little above, then talons forward at the end
			var to := _target - global_position
			var want := to.normalized() * swoop_speed
			velocity = velocity.lerp(want, 1.0 - exp(-3.0 * delta))
			global_position += velocity * delta
			_catch(0.75)
			if to.length() < 0.5 or global_position.y < _target.y - 0.3 or _state_t > 4.0:
				_rest_left = rest
				_go(State.CLIMB)
		State.CLIMB:
			# Beating back up to the perch, then gliding in the last stretch
			var aim := perch + Vector3.UP * 0.8
			_steer(aim, 5.0, delta)
			if global_position.distance_to(aim) < 2.0 or _state_t > 8.0:
				_go(State.LAND)
		State.LAND:
			_steer(perch, 2.5, delta)
			if global_position.distance_to(perch) < 0.12 or _state_t > 3.0:
				global_position = perch
				_go(State.PERCH)
		State.KNOCKED:
			velocity.y -= 6.0 * delta
			global_position += velocity * delta
			_spin += delta * 10.0
			if _state_t > 0.9:
				_spin = 0.0
				_go(State.AWAY)
		State.AWAY:
			_steer(perch + Vector3(0.0, 6.0, 0.0), 6.0, delta)
			if _state_t > 3.0:
				_rest_left = rest * 1.5
				_go(State.CLIMB)
	_pose(delta)


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


func _face(point: Vector3, rate: float) -> void:
	var to := point - global_position
	if Vector2(to.x, to.z).length() > 0.05:
		rotation.y = lerp_angle(rotation.y, atan2(to.x, to.z), clampf(rate, 0.0, 1.0))


## Hit by his tail: knocked tumbling away.
func tail_hit(_from: Vector3, push: Vector3) -> void:
	if state == State.KNOCKED or state == State.AWAY or state == State.PERCH or state == State.STARE:
		return
	velocity = push * 0.9 + Vector3.UP * 3.0
	_hit_done = true
	_go(State.KNOCKED)


func _pose(delta: float) -> void:
	var flat := Vector3(velocity.x, 0.0, velocity.z)
	var flying := state != State.PERCH and state != State.STARE
	if flying and state != State.KNOCKED and flat.length() > 0.3:
		var yaw := atan2(flat.x, flat.z)
		var turn := angle_difference(rotation.y, yaw)
		rotation.y = lerp_angle(rotation.y, yaw, 1.0 - exp(-5.0 * delta))
		rotation.z = lerp_angle(rotation.z, -clampf(turn * 1.5, -0.5, 0.5), 1.0 - exp(-4.0 * delta))
	else:
		rotation.z = lerp_angle(rotation.z, 0.0, 1.0 - exp(-6.0 * delta))
	bird.rotation = Vector3(_spin, 0.0, _spin * 0.6)
	bird.fold = 0.0 if flying else 1.0
	bird.tuck = 1.0 if flying and state != State.LAND else 0.0
	bird.flare = 0.0
	match state:
		State.PERCH, State.STARE:
			bird.flap = 0.0
		State.SWOOP:
			# (silent: no beats at all; talons forward as it closes)
			bird.flap = 0.0
			bird.flare = 0.6 if global_position.distance_to(_target) < 2.2 else 0.0
		State.CLIMB, State.AWAY, State.KNOCKED:
			bird.flap = 1.0
		State.LAND:
			bird.flap = 0.0
			bird.flare = 1.0 if global_position.distance_to(perch) < 1.2 else 0.3
	# Its head on him, wherever he is (an owl turns its head right round); staring, it does not blink
	bird.look_at_point(_him() if player and state != State.KNOCKED else Vector3.INF)
	if state == State.STARE:
		bird._blink = 1.0
		bird._blink_wait = 1.0
