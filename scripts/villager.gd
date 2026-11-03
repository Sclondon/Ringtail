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
## and turn to look at the hero as he comes near; those with `lines` say them in speech bubbles (Chatter). On collision layer
## 4, seeing only the world, as his band are: it never blocks him.

signal jumped
signal landed(impact_speed: float)
signal respawned

enum Doing { STAND, STROLL, SIT, GROOM, SNIFF, RUMMAGE, PLAY, GO, FOLLOW, FLEE, TALK, CHAT, CLIMB, CELEBRATE }
## What kits (and now and then grown-ups) play: tag round the grove, chasing round a tree, pouncing at each other,
## hide and seek in the tall grass, pestering a grown-up.
enum Play { TAG, TREE, POUNCE, HIDE, PESTER }

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
## The giant of the grove (Villagers.GIANT): a gentle huge one that mostly dozes, solid to stand on and climb.
var giant := false
var _solid: AnimatableBody3D
var _solid_shape: CylinderShape3D
## Lost (LostKits): it stays on its spot until found.
var stays := false
var dead := false
## Its name, and what it says, a line at a time in a bubble over its head (empty: it has nothing to say).
var display_name := ""
var lines: PackedStringArray = []
## At the grove: where it keeps to. In the town: the haunts it goes round, and which it is making for.
var home := Vector3.INF
var route: Array[Vector3] = []
var leg := 0
## A kit out with its parent: whom it follows.
var parent: Villager
## A lost kit he has found: him, whom it follows home to the grove (LostKits).
var leader: Node3D
## Kits at play: whom it is chasing (or running from), and which way round.
## Its own build (Villagers._random_build): size, girth, head, ears, tail, fur.
var build := {}
var playmate: Villager
var chasing := false
var play := Play.TAG
## Chatting (Villagers sets it up): whom with, where to stand, and whether it is its turn to talk.
var chat_with: Villager
var chat_spot := Vector3.ZERO
var speaking := false
## Climbing a tree (CLIMB): which, how far up it is going, which way is out from the trunk, and what part of it
## it is at (0 going to it, 1 up, 2 holding on up there, 3 down).
var _tree: Node3D
var _climb_to := 0.0
var _out := Vector3.BACK
var _climb_phase := 0
## Up a giant fir to a platform (Villagers.firs): the platform's top (else INF), the spot on it, and the place on the
## bark it went up by.
var _perch := Vector3.INF
var _perch_spot := Vector3.ZERO
var _grip := Vector3.ZERO
var _napping := false
var _play_centre := Vector3.ZERO
var _hide_spot := Vector3.INF

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
	if giant:
		walk_speed = 1.0
		run_speed = 1.8
		sprint_speed = 2.2
		_make_solid()
	# (what it does first is chosen once it knows where it belongs)
	_go(Doing.STAND, randf_range(0.2, 1.2))


## What it is doing, for BakedMotion: a state baked as its own clip (tools/bake_raccoons.gd), "live" while it climbs,
## or "" to go by its speed.
func baked_state() -> String:
	if rig.climbing_npc:
		return "live"
	if sit_progress > 0.5:
		if rig.lounge > 0.5:
			return "lounge"
		if _napping:
			return "nap"
		if rub_progress < 1.0:
			return "groom"
		if rig.talking > 0.5:
			return "sit_talk"
		if rig.listening > 0.5:
			return "sit_listen"
		return "sit"
	if rig.cheer > 0.5:
		return "cheer"
	if rig.clap > 0.5:
		return "clap"
	if is_ducking:
		return "rummage"
	if Vector2(velocity.x, velocity.z).length() < 0.3:
		if rig.talking > 0.5:
			return "talk"
		if rig.listening > 0.5:
			return "listen"
	return ""


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
	if global_position.y < World.KILL_Y:
		die(velocity)
		return
	for car: Node in get_tree().get_nodes_in_group(&"cars"):
		var body := car as Node3D
		var moving: float = car.get(&"speed") if car.get(&"speed") is float else 0.0
		if body == null or moving < 1.5:
			continue
		# (within the vehicle's own box: HazardCar.half_size, a bus far longer than a car)
		var half: Vector3 = car.get(&"half_size") if car.get(&"half_size") is Vector3 else Vector3(1.0, 0.8, 2.3)
		var local := body.to_local(global_position)
		if absf(local.x) < half.x + 0.05 and absf(local.z) < half.z + 0.1 and local.y < half.y * 2.0 - 0.3:
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
	# (talking or listening, in the rig's own pose for it: chatting, or saying its lines to him)
	var at_chat := doing == Doing.CHAT and _at(chat_spot, 0.3)
	rig.talking = 1.0 if (at_chat and speaking) or _bubble_open() else 0.0
	rig.listening = 1.0 if at_chat and not speaking else 0.0
	# (celebrating: arms up and jumping, the giant clapping; the giant lounges back as it dozes)
	var party := doing == Doing.CELEBRATE
	rig.cheer = 1.0 if party and not giant else 0.0
	rig.clap = 1.0 if party and giant else 0.0
	rig.lounge = 1.0 if giant and doing == Doing.SIT else 0.0
	# (up a tree it holds on and goes up and down it by itself, nothing pushing it about)
	if doing == Doing.CLIMB and _climb_phase > 0:
		_t -= delta
		_climbing(delta)
		return
	_t -= delta

	if giant:
		_keep_solid()
	# What its mind is on
	# (the giant fears nothing)
	if doing != Doing.TALK and not giant:
		var threat := villagers.threat_near(global_position, 3.2 if route.is_empty() else 3.8)
		if threat != Vector3.INF:
			_flee_from = threat
			if doing == Doing.CHAT:
				villagers.end_chat(self)
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
			if leader:
				# (at his heels, each a little way behind and to one side of him, coming at a bound when left behind)
				var yaw: float = leader.get(&"facing_yaw") if &"facing_yaw" in leader else leader.rotation.y
				var back := -Vector3(sin(yaw), 0.0, cos(yaw))
				var heel_at := leader.global_position + back * (1.0 + fposmod(_seed, 1.0) * 1.2) + back.cross(Vector3.UP) * sin(_seed * 7.0) * 0.8
				want = _toward(heel_at, 1.4)
			else:
				var heel := parent.global_position - parent.global_basis.z * 0.55 + parent.global_basis.x * sin(Time.get_ticks_msec() * 0.0011 + _seed) * 0.45
				want = _toward(heel, 1.0)
			if leader == null and parent.doing != Doing.GO and _t <= 0.0:
				# (its parent busy, it darts off to nose about and comes back)
				_go(Doing.SNIFF if randf() < 0.5 else Doing.FOLLOW, randf_range(1.0, 2.5))
		Doing.PLAY:
			want = _play(delta)
		Doing.CELEBRATE:
			# (the kits racing round in a ring; the grown-ups jumping where they are, now and then spinning)
			if kit and home != Vector3.INF:
				_play_angle += delta * 3.2
				want = _toward(home + Vector3(cos(_play_angle), 0.0, sin(_play_angle)) * 2.0, 1.0)
			if not giant and is_on_floor() and randf() < delta * 2.2:
				_pounce_now = true
				if randf() < 0.3:
					_spin_left = TAU
		Doing.CHAT:
			# (to its place a step from the other, and there it stays, turned to it)
			want = _toward(chat_spot, 0.4)
			settle = at_chat
		Doing.CLIMB:
			# (to the foot of the tree, and then up it: _climbing)
			var foot := _tree_foot()
			# (no way to its foot, among roots or round a wall: it gives the tree up)
			if _stuck > 2.5:
				_stuck = 0.0
				_tree = null
				_choose()
				foot = global_position
			want = _toward(foot, 0.8)
			if _at(foot, 0.35):
				_start_climb()
		Doing.FLEE:
			var away := global_position - _flee_from
			away.y = 0.0
			want = (away.normalized() if away.length() > 0.01 else Vector3.BACK) * sprint_speed * 1.2
		Doing.RUMMAGE:
			# (nosing about in one spot)
			want = Vector3(sin(Time.get_ticks_msec() * 0.006 + _seed), 0.0, cos(Time.get_ticks_msec() * 0.005 + _seed)) * 0.18
		_:
			settle = true
	if home != Vector3.INF and doing != Doing.FLEE and doing != Doing.PLAY and doing != Doing.CHAT and doing != Doing.CLIMB:
		# (at the grove it never wanders far from its place)
		var off := Vector3(home.x - global_position.x, 0.0, home.z - global_position.z)
		if off.length() > 3.5:
			want += off.normalized() * (off.length() - 3.5) * 2.0
	# (the giant is not shoved about by those standing on it or climbing it)
	if not giant:
		want += villagers.apart(self) * 4.0
	if hero_flat.length() < 0.7 and not giant:
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
		if want.length() > 1.0 and _blocked(want) and not giant:
			vy = 4.6 if kit else 5.4
			jumped.emit()
		elif _pounce_now:
			# (a pounce at its playmate, or a hop round the grown-up it is pestering)
			_pounce_now = false
			vy = 3.4
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
	if _spin_left > 0.0:
		var turn := minf(_spin_left, delta * 14.0)
		rotation.y += turn
		_spin_left -= turn
	elif party and not kit:
		rotation.y = lerp_angle(rotation.y, atan2(hero_flat.x, hero_flat.z), 1.0 - exp(-6.0 * delta))
	elif at_chat and chat_with:
		var to_other := chat_with.global_position - global_position
		rotation.y = lerp_angle(rotation.y, atan2(to_other.x, to_other.z), 1.0 - exp(-6.0 * delta))
	elif flat.length() > 0.15 and doing != Doing.RUMMAGE:
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
	remove_from_group(&"talkers")
	set_physics_process(false)
	collision_layer = 0
	collision_mask = 0
	if rig.process_mode == Node.PROCESS_MODE_DISABLED:
		rig.process_mode = Node.PROCESS_MODE_INHERIT
		rig.visible = true
	rig.go_limp(push)


## Gives it a name and its lines ([name, line, line...]), and makes it one to talk to.
func say(entry: Array) -> void:
	display_name = entry[0]
	lines = PackedStringArray(entry.slice(1))
	add_to_group(&"talkers")


## Whether it has a word for him.
func talks() -> bool:
	return not lines.is_empty()


## Whether the hero is near enough to talk to it.
func in_reach(hero: Node3D) -> bool:
	return not dead and doing != Doing.FLEE and hero.global_position.distance_to(global_position) < (1.5 if kit else 1.9)


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
	if giant:
		_giant_choose()
		return
	_perch = Vector3.INF
	if chat_with:
		chat_with = null
		speaking = false
	_pestering = null
	if leader:
		_go(Doing.FOLLOW, 1.0)
		return
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
	# Lost (LostKits): it keeps to its spot, a roof or a limb as it may be: no strolling or playing off it
	if stays:
		var pick := randf()
		_go(Doing.SIT if pick < 0.4 else (Doing.SNIFF if pick < 0.65 else (Doing.GROOM if pick < 0.8 else Doing.STAND)), randf_range(2.5, 6.0))
		return
	# (up a giant fir to sit on a platform a while, now and then)
	if home != Vector3.INF and randf() < (0.03 if kit else 0.12) and _begin_perch():
		return
	# At the grove: the kits at play most of the time, up a tree now and then, pestering the grown-ups; the grown-ups
	# up a tree or playing tag once in a while (and chatting: Villagers sets that up)
	var roll_play := randf()
	if kit:
		if roll_play < 0.12 and _begin_climb():
			return
		if roll_play < 0.24 and _start_pester():
			return
		if playmate and not playmate.dead and not playmate.stays and playmate.leader == null and playmate.doing != Doing.CLIMB \
				and playmate.doing != Doing.FLEE and roll_play < 0.85:
			_start_play()
			return
	elif home != Vector3.INF:
		if roll_play < 0.07 and _begin_climb():
			return
		if roll_play < 0.12:
			var other := villagers.idle_adult(self)
			if other:
				playmate = other
				other.playmate = self
				chasing = true
				play = Play.TAG
				_start_play()
				play = Play.TAG
				other.play = Play.TAG
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
	# (now and then on all fours about the place, and up again: the user, 2026-11-02, "raccoons should walk around on all
	# 4s too sometimes"; kits mostly on all fours, now and then up on their hind legs; all stand to talk)
	if rig and not giant and not stays:
		var ambling := to in [Doing.STROLL, Doing.GO, Doing.SNIFF, Doing.RUMMAGE, Doing.FOLLOW]
		if kit:
			rig.always_on_fours = not ((ambling or to == Doing.STAND) and randf() < 0.3) and to != Doing.TALK
		else:
			rig.always_on_fours = ambling and randf() < 0.35


## A level velocity towards `at`, easing off as it gets there; `pace` of its fastest.
func _toward(at: Vector3, pace: float) -> Vector3:
	var seek := Vector3(at.x - global_position.x, 0.0, at.z - global_position.z)
	var far := seek.length()
	if far < 0.25:
		return Vector3.ZERO
	return seek.normalized() * clampf(far * 2.0, 0.0, sprint_speed) * pace


## At play: tag (one runs round the grown-ups, or round a tree, the other chases it, swapping when caught),
## pouncing at each other, hide and seek in the tall grass, or pestering a grown-up.
func _play(delta: float) -> Vector3:
	if play == Play.PESTER:
		if _pestering == null or _pestering.dead:
			return Vector3.ZERO
		# (round and round it, close, with little hops)
		_play_angle += delta * 2.6
		if is_on_floor() and randf() < delta * 1.5:
			_pounce_now = true
		return _toward(_pestering.global_position + Vector3(cos(_play_angle), 0.0, sin(_play_angle)) * 0.55, 1.0)
	if playmate == null or playmate.dead:
		return Vector3.ZERO
	if play == Play.POUNCE:
		# (squaring up to each other, then a pounce, and again)
		var gap := playmate.global_position - global_position
		gap.y = 0.0
		if gap.length() < 0.9 and is_on_floor() and randf() < delta * 1.4:
			_pounce_now = true
			if rig:
				rig.express(&"surprised", 0.6)
		if gap.length() < 0.55:
			return -gap.normalized() * 1.2
		return _toward(playmate.global_position, 0.5)
	if play == Play.HIDE and _hide_spot != Vector3.INF:
		if not chasing:
			# (off into the tall grass, and down in it, still)
			return _toward(_hide_spot, 1.0)
		# (counting first, then looking, nose down; found: the game is over)
		if _t > 6.0:
			return Vector3.ZERO
		if _at(playmate.global_position, 0.6):
			if rig:
				rig.express(&"happy", 1.5)
			_t = 0.0
			playmate._t = 0.0
		return _toward(playmate.global_position + Vector3(sin(_t * 2.0), 0.0, cos(_t * 1.7)) * 0.8, 0.45)
	var centre := _play_centre if play == Play.TREE else home
	if chasing:
		var gap := playmate.global_position - global_position
		gap.y = 0.0
		if gap.length() < 0.35 and randf() < delta * 3.0:
			# (caught: now the other one is it)
			chasing = false
			playmate.chasing = true
			_play_angle = atan2(global_position.z - centre.z, global_position.x - centre.x)
		return _toward(playmate.global_position, 0.95)
	_play_angle += delta * (1.3 + 0.4 * sin(Time.get_ticks_msec() * 0.0017 + _seed)) * (1.6 if play == Play.TREE else 1.0)
	var radius := (1.3 if play == Play.TREE else 2.2) + 0.6 * sin(Time.get_ticks_msec() * 0.0009 + _seed) * (0.3 if play == Play.TREE else 1.0)
	return _toward(centre + Vector3(cos(_play_angle), 0.0, sin(_play_angle)) * radius, 1.0)


## Whether something solid is close in front of it, low enough to hop over.
func _blocked(way: Vector3) -> bool:
	# (and low down, a kerb or a step: a steep face only, not the ground rising ahead; they stuck at the pavement's
	# edge: the user, 2026-11-02, "the boiding kits get stuck on the sidewalk in the road")
	for high: float in [0.18, 0.05]:
		var from := global_position + Vector3.UP * high
		var query := PhysicsRayQueryParameters3D.create(from, from + way.normalized() * 0.4, 1)
		query.exclude = [get_rid()]
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty() and (hit.normal as Vector3).y < 0.6:
			return true
	return false


## Whether it is there (across the ground), near enough.
func _at(spot: Vector3, near: float) -> bool:
	return Vector2(spot.x - global_position.x, spot.z - global_position.z).length() < near


## Whether its speech bubble is up (saying its lines to him, or chatting).
func _bubble_open() -> bool:
	var bubble: SpeechBubble = villagers.talk._bubbles.get(self) if villagers.talk else null
	return bubble != null and bubble.openness > 0.3


# --- Climbing a tree (the user, 2026-11-02: "npcoons should also be playing with each other and climbing trees") ---

## Off to climb a tree near its place, if there is one nobody else is up: true if so.
func _begin_climb() -> bool:
	var near := home if home != Vector3.INF else global_position
	var choices: Array[Node3D] = []
	for node in get_tree().get_nodes_in_group(&"climbable"):
		var tree := node as Node3D
		# (a tree stands where it grows; a mesh of many poles sits at the middle of the world)
		if tree == null or tree.global_position.length() < 2.0 or tree.global_position.distance_to(near) > 32.0:
			continue
		if villagers.tree_taken(tree, self):
			continue
		choices.append(tree)
	if choices.is_empty():
		return false
	_tree = choices[randi() % choices.size()]
	_out = Vector3(global_position.x - _tree.global_position.x, 0.0, global_position.z - _tree.global_position.z)
	_out = _out.normalized() if _out.length() > 0.05 else Vector3.BACK
	_climb_to = randf_range(2.0, 4.5 if kit else 3.5)
	_climb_phase = 0
	_go(Doing.CLIMB, 25.0)
	return true


## Where its trunk is, on the side it came from, at `height` over the foot of the tree: the point a hand from its bark
## (Vector3.INF where there is no trunk there: above it).
func _trunk_at(height: float) -> Vector3:
	var y := _tree.global_position.y + height
	var centre := Vector3(_tree.global_position.x, y, _tree.global_position.z)
	var query := PhysicsRayQueryParameters3D.create(centre + _out * 3.0, centre, 1)
	query.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return Vector3.INF
	return (hit.position as Vector3) + _out * (0.16 if kit else 0.22)


## The foot of the tree, where it starts up.
func _tree_foot() -> Vector3:
	var at := _trunk_at(0.5)
	return at if at != Vector3.INF else _tree.global_position + _out * 0.8


func _start_climb() -> void:
	_climb_phase = 1
	collision_mask = 0
	velocity = Vector3.ZERO
	rig.climbing_npc = true
	_grip = global_position


## Up the trunk, holding on a while up there looking about, and down again; moved along it, nothing pushing it.
## Going to a fir's platform it goes straight up the bark (the platforms round it would catch a ray to the trunk),
## steps out onto it, walks to a spot, sits there a while (napping, or chatting with one on the same platform), then
## walks back to the bark and climbs down under it.
func _climbing(delta: float) -> void:
	if not is_instance_valid(_tree):
		_end_climb()
		return
	var height := global_position.y - _tree.global_position.y
	var perching := _perch != Vector3.INF
	match _climb_phase:
		1:
			var on := Vector3(_grip.x, 0.0, _grip.z) if perching else _trunk_at(height + 0.35)
			if on == Vector3.INF or height >= _climb_to:
				if perching:
					# (up through the platform's edge, onto it)
					global_position.y = _perch.y + 0.05
					rig.climbing_npc = false
					# (on the platform it walks and sits on it as on the ground)
					collision_mask = 1
					var a := randf() * TAU
					_perch_spot = _perch + Vector3(cos(a), 0.0, sin(a)) * randf_range(0.0, 0.9)
					_climb_phase = 4
					return
				# (as high as it goes: it holds on there)
				_climb_phase = 2
				_t = randf_range(4.0, 8.0)
				velocity = Vector3.ZERO
			else:
				var up := (1.6 if kit else 1.3) * delta
				global_position = Vector3(on.x, global_position.y + up, on.z)
				velocity = Vector3(0.0, up / delta, 0.0)
		2:
			velocity = Vector3.ZERO
			if _t <= 0.0:
				_climb_phase = 3
		3:
			var down := (1.8 if kit else 1.5) * delta
			var query := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 0.1, global_position + Vector3.DOWN * 0.4, 1)
			query.exclude = [get_rid()]
			var ground := get_world_3d().direct_space_state.intersect_ray(query)
			var on := Vector3(_grip.x, 0.0, _grip.z) if perching else _trunk_at(height)
			if on != Vector3.INF:
				global_position = Vector3(on.x, global_position.y, on.z)
			if not ground.is_empty() and global_position.y - (ground.position as Vector3).y < down + 0.02:
				global_position.y = (ground.position as Vector3).y
				_end_climb()
				return
			global_position.y -= down
			velocity = Vector3(0.0, -down / delta, 0.0)
		4, 6:
			# (walking along the platform, to its spot or back to the bark)
			var to := (_perch_spot if _climb_phase == 4 else Vector3(_grip.x, _perch.y, _grip.z)) - global_position
			to.y = 0.0
			# (back at the bark, or off the platform's inner edge going to it: down it goes)
			if to.length() <= (0.12 if _climb_phase == 4 else 0.45) or (_climb_phase == 6 and not is_on_floor()):
				velocity = Vector3.ZERO
				if _climb_phase == 4:
					_climb_phase = 5
					_t = randf_range(15.0, 35.0)
					_napping = randf() < 0.4
				else:
					_down_from_platform()
			else:
				velocity = to.normalized() * walk_speed * 0.8
				rotation.y = lerp_angle(rotation.y, atan2(to.x, to.z), 1.0 - exp(-9.0 * delta))
			sit_progress = move_toward(sit_progress, 0.0, delta * 3.0)
			if _climb_phase != 3:
				_on_platform(delta)
			return
		5:
			_perched(delta)
			_on_platform(delta)
			return
	# (belly to the trunk)
	rotation.y = atan2(-_out.x, -_out.z)
	var hero := villagers.player
	if hero and hero.global_position.distance_to(global_position) < 6.0:
		rig._interest = hero
		rig._interest_is_threat = false


## On a platform: moved as on the ground (stepping off it, it takes hold of the bark and goes down).
func _on_platform(delta: float) -> void:
	velocity.y = -0.1 if is_on_floor() else velocity.y - 20.0 * delta
	move_and_slide()
	if global_position.y < _perch.y - 1.0:
		_down_from_platform()


## Onto the bark under the platform, and down.
func _down_from_platform() -> void:
	_napping = false
	rig.climbing_npc = true
	collision_mask = 0
	velocity = Vector3.ZERO
	global_position = Vector3(_grip.x, minf(global_position.y, _perch.y - 0.6), _grip.z)
	_climb_phase = 3


## Sat on a platform: napping, or turned to another on the same platform chatting, or looking out; then back down.
func _perched(delta: float) -> void:
	velocity = Vector3(0.0, velocity.y, 0.0)
	sit_progress = move_toward(sit_progress, 1.0, delta * 0.9)
	var mate: Villager
	for other in villagers.members:
		if other != self and other._climb_phase == 5 and other._perch == _perch and not other._napping:
			mate = other
	if _napping:
		rig.express(&"sleepy", 0.5)
	elif mate:
		var to_mate := mate.global_position - global_position
		rotation.y = lerp_angle(rotation.y, atan2(to_mate.x, to_mate.z), 1.0 - exp(-6.0 * delta))
		# (turn about: whose turn by the clock, the two always opposite)
		var turn := int(Time.get_ticks_msec() / 2600) % 2 == (0 if get_instance_id() < mate.get_instance_id() else 1)
		rig.talking = 1.0 if turn else 0.0
		rig.listening = 0.0 if turn else 1.0
	else:
		# (looking out from up there, away from the trunk)
		rotation.y = lerp_angle(rotation.y, atan2(_out.x, _out.z), 1.0 - exp(-2.0 * delta))
	if _t <= 0.0:
		_napping = false
		_climb_phase = 6


func _end_climb() -> void:
	_climb_phase = 0
	collision_mask = 1
	velocity = Vector3.ZERO
	rig.climbing_npc = false
	_tree = null
	_perch = Vector3.INF
	_napping = false
	_choose()


## Off to sit on a platform up a giant fir near home (not one that has two on it already), if there is one.
func _begin_perch() -> bool:
	var near := home if home != Vector3.INF else global_position
	var choices: Array = []
	for fir in villagers.firs:
		if fir.global_position.distance_to(near) > 45.0:
			continue
		for perch: Vector3 in fir.get_meta(&"perches"):
			if villagers.up_fir(fir, perch) < 2:
				choices.append([fir, perch])
	if choices.is_empty():
		return false
	var pick: Array = choices[randi() % choices.size()]
	_tree = pick[0]
	_perch = pick[1]
	_out = Vector3(_perch.x - _tree.global_position.x, 0.0, _perch.z - _tree.global_position.z).normalized()
	_climb_to = _perch.y - _tree.global_position.y
	_climb_phase = 0
	_go(Doing.CLIMB, 120.0)
	return true


# --- Play (the user, 2026-11-02: "npcoons should also be playing with each other") ---

## Sets it and its playmate playing one game or another: tag, round a tree, pouncing, hide and seek in tall grass.
func _start_play() -> void:
	var kinds: Array[Play] = [Play.TAG, Play.TAG, Play.POUNCE]
	var tree := _near_tree()
	if tree:
		kinds.append(Play.TREE)
	var grass := _near_tall_grass()
	if grass != Vector3.INF:
		kinds.append(Play.HIDE)
	play = kinds[randi() % kinds.size()]
	_play_centre = tree.global_position if play == Play.TREE else home
	_hide_spot = grass
	_go(Doing.PLAY, randf_range(6.0, 11.0))
	_play_angle = randf() * TAU
	playmate.play = play
	playmate._play_centre = _play_centre
	playmate._hide_spot = _hide_spot
	playmate.doing = Doing.PLAY
	playmate._t = _t
	playmate.chasing = not chasing
	if play == Play.HIDE:
		# (the one that is "it" counts first, then goes looking)
		chasing = randf() < 0.5
		playmate.chasing = not chasing


## A kit pestering a grown-up: hopping round it close, the grown-up putting up with it.
func _start_pester() -> bool:
	for other in villagers.members:
		if other != self and not other.kit and not other.dead and other.home != Vector3.INF and _at(other.global_position, 6.0):
			playmate = other if playmate == null else playmate
			_pestering = other
			play = Play.PESTER
			_go(Doing.PLAY, randf_range(4.0, 7.0))
			if other.rig:
				other.rig.express(&"sleepy", 3.0)
			return true
	return false


var _pestering: Villager
var _pounce_now := false
var _spin_left := 0.0


## Glad: it turns to him and celebrates a few seconds (Villagers.celebrate), then goes back to what it was doing.
func celebrate() -> void:
	if dead or stays or leader or (doing == Doing.CLIMB and _climb_phase > 0) or doing == Doing.FLEE:
		return
	_tree = null
	if chat_with:
		villagers.end_chat(self)
	_go(Doing.CELEBRATE, randf_range(3.0, 4.5))
	_play_angle = randf() * TAU
	if rig:
		rig.express(&"happy", _t)


func _near_tree() -> Node3D:
	var near := home if home != Vector3.INF else global_position
	for node in get_tree().get_nodes_in_group(&"climbable"):
		var tree := node as Node3D
		if tree and tree.global_position.length() > 2.0 and tree.global_position.distance_to(near) < 32.0:
			return tree
	return null


func _near_tall_grass() -> Vector3:
	var lawn := TownGrass.current
	if lawn == null:
		return Vector3.INF
	var near := home if home != Vector3.INF else global_position
	for patch in lawn._tall:
		var at := Vector3(patch.x, near.y, patch.y)
		if Vector2(patch.x - near.x, patch.y - near.z).length() < 18.0:
			return at
	return Vector3.INF


# --- The giant of the grove (the user, 2026-11-02: "1 giant Totoro-sized raccoon") ---

## Its body to stand on and climb: a broad drum, as tall as it is sitting or standing, following it about (on the
## world's layer, so he lands on it and scurries up it; in the group `climbable`, so the kits climb it too).
func _make_solid() -> void:
	_solid = AnimatableBody3D.new()
	_solid.name = "GiantBody"
	# (not synced to the physics step: synced, it kept the place it was made at, not where the giant settled)
	_solid.sync_to_physics = false
	_solid_shape = CylinderShape3D.new()
	# (sized to it: 0.92 m round its belly at size 4)
	_solid_shape.radius = 0.23 * rig.scale.x
	_solid_shape.height = 3.0
	var shape := CollisionShape3D.new()
	shape.shape = _solid_shape
	shape.position.y = 1.5
	_solid.add_child(shape)
	_solid.add_to_group(&"climbable")
	# (a child of it, so it goes where it goes; setting a top-level one's place each step did not take)
	add_child(_solid)
	# (it stands where it is: its own small capsule does not block the others; the drum does)
	add_collision_exception_with(_solid)


func _keep_solid() -> void:
	if _solid == null:
		return
	# (its lap and belly, not its whole height: up there he stands on its belly, below its head)
	var tall := lerpf(0.34, 0.25, sit_progress) * rig.scale.x
	_solid_shape.height = tall
	(_solid.get_child(0) as CollisionShape3D).position.y = tall * 0.5


## What the giant does: dozes sitting, mostly (a long while, sleepy-eyed), scratches itself, stands a while looking
## about (the rig's idles: a big stretch, a yawn of a neck crack), and now and then plods a few slow steps.
func _giant_choose() -> void:
	var roll := randf()
	if roll < 0.6:
		_go(Doing.SIT, randf_range(14.0, 28.0))
		rig.express(&"sleepy", _t)
	elif roll < 0.75:
		_go(Doing.GROOM, randf_range(5.0, 8.0))
		rub_progress = 1.0
	elif roll < 0.92:
		_go(Doing.STAND, randf_range(6.0, 12.0))
	else:
		var a := randf() * TAU
		_goal = home + Vector3(cos(a), 0.0, sin(a)) * randf_range(0.8, 2.0)
		_pace = 0.3
		_go(Doing.STROLL, randf_range(5.0, 9.0))
