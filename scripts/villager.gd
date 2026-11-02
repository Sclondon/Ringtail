class_name Villager
extends CharacterBody3D
## One of the other raccoons of the town (the user, 2026-11-02: "There should be other raccons in the center of the
## grove to talk to", "kits and adults", "And there should be other raccons just running around the map doing
## stuff"). A body with a small mind of its own, posed by the hero's own rig (RaccoonRig) at its own size: an adult
## near his, a kit small with a big head (Villagers.make).
##
## At the grove (`home` set): it keeps near its place there, standing about, sitting, washing its face, sniffing,
## strolling a step or two; kits chase one another round the grown-ups. Out in the town (`route` set): it goes from
## haunt to haunt along the route, at a lope, and at each does a little something (rummages, sniffs, sits, washes).
## A kit with a `parent` keeps at its heels, darting off and back. All of them run from danger (Villagers.threat_near)
## and turn to look at the hero as he comes near; those with `lines` can be talked to (TalkBox). On collision layer
## 4, seeing only the world, as his band are: it never blocks him.

signal jumped
signal landed(impact_speed: float)
signal respawned

enum Doing { STAND, STROLL, SIT, GROOM, SNIFF, RUMMAGE, PLAY, GO, FOLLOW, FLEE, TALK }

## (what the rig reads of a body)
var walk_speed := 1.0
var run_speed := 4.4
var sprint_speed := 6.0
var is_pushing := false
var is_ducking := false
var is_crawling := false
var is_sprinting := false
var air_time := 0.0
var sit_progress := 0.0
var rub_progress := 1.0

var villagers: Villagers
var rig: RaccoonRig
var kit := false
var dead := false
## What it says, a line at a time (empty: it has nothing to say).
var lines: PackedStringArray = []
## At the grove: where it keeps to. In the town: the haunts it goes round, and which it is making for.
var home := Vector3.INF
var route: Array[Vector3] = []
var leg := 0
## A kit out with its parent: whom it follows.
var parent: Villager
## Kits at play: whom it is chasing (or running from), and which way round.
var playmate: Villager
var chasing := false

var doing := Doing.STAND
var _t := 0.0
var _goal := Vector3.ZERO
var _pace := 1.0
var _flee_from := Vector3.ZERO
var _was_floor := true
var _fall_speed := 0.0
var _stuck := 0.0
var _seed := 0.0
var _play_angle := 0.0
var _far := false


func _ready() -> void:
	collision_layer = 4
	collision_mask = 1
	var shape := CapsuleShape3D.new()
	shape.radius = 0.12 if kit else 0.18
	shape.height = 0.36 if kit else 0.55
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.rotation.x = PI / 2
	collider.position.y = shape.radius + 0.02
	add_child(collider)
	add_child(rig)
	_seed = randf() * 100.0
	if kit:
		walk_speed = 0.7
		run_speed = 3.2
		sprint_speed = 4.6
	# (what it does first is chosen once it knows where it belongs)
	_go(Doing.STAND, randf_range(0.2, 1.2))


func _physics_process(delta: float) -> void:
	var hero := villagers.player
	if hero == null:
		return
	var to_hero := hero.global_position - global_position
	var hero_flat := Vector3(to_hero.x, 0.0, to_hero.z)
	# (far off, the rig is put to sleep and it only keeps going along)
	var far := hero_flat.length() > 45.0
	if far != _far:
		_far = far
		rig.process_mode = Node.PROCESS_MODE_DISABLED if far else Node.PROCESS_MODE_INHERIT
		rig.visible = not far
	# (it is never put back anywhere: off the bottom of the world, or hit by a car, it is dead; the user,
	# 2026-11-02, "the kits should not teleport to you, and if they die they should just rag doll and stop moving")
	if global_position.y < -20.0:
		die(velocity)
		return
	for car: Node in get_tree().get_nodes_in_group(&"cars"):
		var body := car as Node3D
		var moving: float = car.get(&"speed") if car.get(&"speed") is float else 0.0
		if body == null or moving < 1.5:
			continue
		# (within the car's own box: about 2 m wide, 4.6 m long)
		var local := body.to_local(global_position)
		if absf(local.x) < 1.05 and absf(local.z) < 2.3 and local.y < 1.6:
			var away := global_position - body.global_position
			away.y = 0.0
			die(away.normalized() * moving + Vector3.UP * 3.0)
			return
	# (a kit whose grown-up is dead goes on round the haunts by itself)
	if parent and parent.dead:
		route = parent.route
		leg = parent.leg
		parent = null
		_choose()
	_t -= delta

	# What its mind is on
	if doing != Doing.TALK:
		var threat := villagers.threat_near(global_position, 3.2 if route.is_empty() else 3.8)
		if threat != Vector3.INF:
			_flee_from = threat
			if doing != Doing.FLEE:
				_go(Doing.FLEE, randf_range(1.2, 2.0))
	match doing:
		Doing.TALK:
			pass
		Doing.FLEE:
			if _t <= 0.0:
				_choose()
		_:
			if _t <= 0.0 or (doing == Doing.GO and _arrived()):
				_choose()

	# Where it wants to be, and how fast
	var want := Vector3.ZERO
	var settle := false
	match doing:
		Doing.STROLL, Doing.GO:
			want = _toward(_goal, _pace)
		Doing.FOLLOW:
			var heel := parent.global_position - parent.global_basis.z * 0.55 + parent.global_basis.x * sin(Time.get_ticks_msec() * 0.0011 + _seed) * 0.45
			want = _toward(heel, 1.0)
			if parent.doing != Doing.GO and _t <= 0.0:
				# (its parent busy, it darts off to nose about and comes back)
				_go(Doing.SNIFF if randf() < 0.5 else Doing.FOLLOW, randf_range(1.0, 2.5))
		Doing.PLAY:
			want = _play(delta)
		Doing.FLEE:
			var away := global_position - _flee_from
			away.y = 0.0
			want = (away.normalized() if away.length() > 0.01 else Vector3.BACK) * sprint_speed * 1.2
		Doing.RUMMAGE:
			# (nosing about in one spot)
			want = Vector3(sin(Time.get_ticks_msec() * 0.006 + _seed), 0.0, cos(Time.get_ticks_msec() * 0.005 + _seed)) * 0.18
		_:
			settle = true
	if home != Vector3.INF and doing != Doing.FLEE and doing != Doing.PLAY:
		# (at the grove it never wanders far from its place)
		var off := Vector3(home.x - global_position.x, 0.0, home.z - global_position.z)
		if off.length() > 3.5:
			want += off.normalized() * (off.length() - 3.5) * 2.0
	want += villagers.apart(self) * 4.0
	if hero_flat.length() < 0.7:
		want -= hero_flat.normalized() * (0.7 - hero_flat.length()) * 5.0
	want = want.limit_length(sprint_speed * 1.2)

	is_ducking = doing == Doing.RUMMAGE
	var sitting := settle and (doing == Doing.SIT or doing == Doing.GROOM)
	sit_progress = move_toward(sit_progress, 1.0 if sitting else 0.0, delta * (0.9 if sitting else 3.0))
	if doing == Doing.GROOM and sit_progress > 0.95:
		# (washing its face, over and over with a pause between)
		if rub_progress >= 1.0 and randf() < delta * 0.6:
			rub_progress = 0.0
		rub_progress = minf(rub_progress + delta / 2.4, 1.0)
	elif rub_progress < 1.0:
		rub_progress = minf(rub_progress + delta / 0.6, 1.0)

	var on_floor := is_on_floor()
	var flat := Vector3(velocity.x, 0.0, velocity.z).move_toward(want, (24.0 if on_floor else 5.0) * delta)
	var vy := velocity.y
	if on_floor:
		air_time = 0.0
		vy = -0.1
		# (over what is in its way, a hop; stuck a while, it gives that haunt up)
		if want.length() > 1.0 and _blocked(want):
			vy = 4.6 if kit else 5.4
			jumped.emit()
		_stuck = _stuck + delta if want.length() > 1.0 and flat.length() < 0.3 else 0.0
		if _stuck > 2.5 and not route.is_empty():
			_stuck = 0.0
			leg = (leg + 1) % route.size()
			_choose()
	else:
		air_time += delta
		vy -= 20.0 * delta
		_fall_speed = -vy
	velocity = Vector3(flat.x, vy, flat.z)
	is_sprinting = flat.length() > run_speed * 0.7 or (kit and flat.length() > walk_speed * 1.4)
	if flat.length() > 0.15 and doing != Doing.RUMMAGE:
		rotation.y = lerp_angle(rotation.y, atan2(flat.x, flat.z), 1.0 - exp(-9.0 * delta))
	elif hero_flat.length() < 4.0 or doing == Doing.TALK:
		# (still, it turns to the hero as he comes near)
		rotation.y = lerp_angle(rotation.y, atan2(hero_flat.x, hero_flat.z), 1.0 - exp(-4.0 * delta))
	# (and looks at him: the rig's own eye goes to whatever has it, so it is given him while he is near)
	if hero_flat.length() < 4.5 and doing != Doing.FLEE and not far:
		rig._interest = hero
		rig._interest_is_threat = false
	move_and_slide()
	if is_on_floor() and not _was_floor:
		landed.emit(_fall_speed)
		if _fall_speed > SquadRaccoon.DEADLY_FALL:
			die(Vector3.DOWN * _fall_speed * 0.3)
			return
	_was_floor = is_on_floor()


## Killed: it goes limp where it is, a ragdoll, and moves no more of itself (as the hero's band do).
func die(push: Vector3) -> void:
	if dead:
		return
	dead = true
	if villagers.talk and villagers.talk.talking == self:
		villagers.talk.close()
	set_physics_process(false)
	collision_layer = 0
	collision_mask = 0
	if rig.process_mode == Node.PROCESS_MODE_DISABLED:
		rig.process_mode = Node.PROCESS_MODE_INHERIT
		rig.visible = true
	rig.go_limp(push)


## Whether it has a word for him.
func talks() -> bool:
	return not lines.is_empty()


## Stops what it is doing and turns to him to talk (or goes back to it).
func listen(on: bool) -> void:
	if on:
		_go(Doing.TALK, INF)
		if rig:
			rig.express(&"happy", 1.6)
	elif doing == Doing.TALK:
		_choose()


## Picks what to do next.
func _choose() -> void:
	if parent and is_instance_valid(parent):
		_go(Doing.FOLLOW, randf_range(2.0, 5.0))
		return
	if not route.is_empty():
		if doing == Doing.GO and _arrived():
			# (at a haunt: a little something there, most times)
			var roll := randf()
			if roll < 0.3:
				_go(Doing.RUMMAGE, randf_range(2.5, 5.0))
			elif roll < 0.5:
				_go(Doing.SNIFF, randf_range(1.5, 3.0))
				rig._sniff_wait = 0.0
			elif roll < 0.65:
				_go(Doing.SIT, randf_range(2.0, 4.5))
			elif roll < 0.78:
				_go(Doing.GROOM, randf_range(4.0, 6.0))
				rub_progress = 1.0
			else:
				_next_haunt()
			return
		_next_haunt()
		return
	# At the grove
	if kit and playmate and not playmate.dead and randf() < 0.7:
		_go(Doing.PLAY, randf_range(5.0, 9.0))
		_play_angle = randf() * TAU
		playmate.doing = Doing.PLAY
		playmate._t = _t
		playmate.chasing = not chasing
		return
	var roll := randf()
	if roll < 0.28:
		_go(Doing.STAND, randf_range(2.0, 5.0))
	elif roll < 0.48:
		_go(Doing.SIT, randf_range(4.0, 9.0))
	elif roll < 0.62:
		_go(Doing.GROOM, randf_range(4.0, 7.0))
		rub_progress = 1.0
	elif roll < 0.78:
		_go(Doing.SNIFF, randf_range(2.0, 3.5))
		rig._sniff_wait = 0.0
	else:
		var a := randf() * TAU
		_goal = home + Vector3(cos(a), 0.0, sin(a)) * randf_range(0.5, 2.2)
		_pace = 0.35
		_go(Doing.STROLL, randf_range(3.0, 6.0))


func _next_haunt() -> void:
	leg = (leg + 1) % route.size()
	_goal = route[leg] + Vector3(randf_range(-0.8, 0.8), 0.0, randf_range(-0.8, 0.8))
	_pace = randf_range(0.7, 1.0)
	_go(Doing.GO, 40.0)


func _arrived() -> bool:
	return Vector2(_goal.x - global_position.x, _goal.z - global_position.z).length() < 0.6


func _go(to: Doing, seconds: float) -> void:
	doing = to
	_t = seconds


## A level velocity towards `at`, easing off as it gets there; `pace` of its fastest.
func _toward(at: Vector3, pace: float) -> Vector3:
	var seek := Vector3(at.x - global_position.x, 0.0, at.z - global_position.z)
	var far := seek.length()
	if far < 0.25:
		return Vector3.ZERO
	return seek.normalized() * clampf(far * 2.0, 0.0, sprint_speed) * pace


## Kits at play: one runs round the grown-ups and the other chases it, swapping now and then (it is tag).
func _play(delta: float) -> Vector3:
	if playmate == null or playmate.dead:
		return Vector3.ZERO
	if chasing:
		var gap := playmate.global_position - global_position
		gap.y = 0.0
		if gap.length() < 0.35 and randf() < delta * 3.0:
			# (caught: now the other one is it)
			chasing = false
			playmate.chasing = true
			_play_angle = atan2(global_position.z - home.z, global_position.x - home.x)
		return _toward(playmate.global_position, 0.95)
	_play_angle += delta * (1.3 + 0.4 * sin(Time.get_ticks_msec() * 0.0017 + _seed))
	var radius := 2.2 + 0.6 * sin(Time.get_ticks_msec() * 0.0009 + _seed)
	return _toward(home + Vector3(cos(_play_angle), 0.0, sin(_play_angle)) * radius, 1.0)


## Whether something solid is close in front of it, low enough to hop over.
func _blocked(way: Vector3) -> bool:
	var from := global_position + Vector3.UP * 0.18
	var query := PhysicsRayQueryParameters3D.create(from, from + way.normalized() * 0.4, 1)
	query.exclude = [get_rid()]
	return not get_world_3d().direct_space_state.intersect_ray(query).is_empty()
