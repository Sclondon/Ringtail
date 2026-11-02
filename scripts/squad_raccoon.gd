class_name SquadRaccoon
extends CharacterBody3D
## One of the band of little raccoons that scurry about the hero (the user, 2026-11-01: "there should be a squad of
## raccoons that boid around you, that scurry about you with minds of their own"). A body steered by its own small
## mind, posed by the hero's own rig (RaccoonRig, always on all fours) at a smaller size.
##
## Boids: kept apart from the others and from him, drawn to a place of its own on a loose ring about him (behind
## him as he runs), going his way. And a mind of its own: it wanders off to sniff at things near him (food, a trash
## can), comes darting back at a bound when he runs off, scatters from danger (and when he is hurt), hops up after
## him onto something low, and sits when he stands about. On collision layer 4, seeing only the world: it never
## blocks him, takes his food, or pushes the others.

signal jumped
signal landed(impact_speed: float)
signal respawned

enum Mind { FOLLOW, SNIFF, SCATTER, SIT }

## (what the rig reads of a body)
var walk_speed := 1.0
var run_speed := 4.4
var sprint_speed := 6.6
var is_pushing := false
var is_ducking := false
var is_crawling := false
var is_sprinting := false
var air_time := 0.0
var sit_progress := 0.0

var squad: Squad
var index := 0
var mind := Mind.FOLLOW
var rig: RaccoonRig

var _mind_t := 0.0
var _sniff_at: Node3D
var _flee_from := Vector3.ZERO
var _still := 0.0
var _was_floor := true
var _fall_speed := 0.0
var _seed := 0.0
var _sit_spot := Vector3.ZERO


func _ready() -> void:
	collision_layer = 4
	collision_mask = 1
	var shape := CapsuleShape3D.new()
	shape.radius = 0.16
	shape.height = 0.5
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.rotation.x = PI / 2
	collider.position.y = 0.2
	add_child(collider)
	add_child(rig)
	_seed = randf() * 100.0
	_mind_t = randf_range(2.0, 6.0)


func _physics_process(delta: float) -> void:
	var hero := squad.player
	if hero == null:
		return
	_mind_t -= delta
	var to_hero := hero.global_position - global_position
	var flat_to := Vector3(to_hero.x, 0.0, to_hero.z)
	var hero_speed := Vector2(hero.velocity.x, hero.velocity.z).length()
	_still = _still + delta if hero_speed < 0.2 and hero.is_on_floor() else 0.0

	# Far behind (a fall, a climb he cannot follow): put back near him, out of sight behind
	if flat_to.length() > 18.0 or global_position.y < -20.0:
		var behind := -Vector3(sin(hero.facing_yaw), 0.0, cos(hero.facing_yaw))
		var aside := behind.cross(Vector3.UP) * (index - 2) * 0.5
		global_position = hero.global_position + behind * 2.0 + aside + Vector3.UP * 0.3
		velocity = Vector3.ZERO
		mind = Mind.FOLLOW
		respawned.emit()
		return

	# What its mind is on
	var threat := squad.threat_near(global_position, 4.5)
	if threat != Vector3.INF:
		_scatter(threat, 1.6)
	match mind:
		Mind.SCATTER:
			if _mind_t <= 0.0:
				_go(Mind.FOLLOW, randf_range(2.0, 5.0))
		Mind.SNIFF:
			if _mind_t <= 0.0 or not is_instance_valid(_sniff_at) or flat_to.length() > 7.0 or hero_speed > hero.run_speed * 0.8:
				_go(Mind.FOLLOW, randf_range(3.0, 7.0))
		Mind.SIT:
			if _still < 0.5:
				_go(Mind.FOLLOW, randf_range(1.0, 4.0))
		Mind.FOLLOW:
			if _still > 1.5 + index * 0.3:
				# (it sits where its place was when he stopped, not chasing the ring round)
				_sit_spot = squad.slot(index)
				_go(Mind.SIT, 0.0)
			elif _mind_t <= 0.0:
				var thing := squad.something_to_sniff(global_position, hero.global_position, self)
				if thing:
					_sniff_at = thing
					_go(Mind.SNIFF, randf_range(1.8, 3.5))
				else:
					_mind_t = randf_range(2.0, 5.0)

	# Where it wants to be, and how fast
	var goal := squad.slot(index)
	var pace := 1.0
	match mind:
		Mind.SIT:
			goal = _sit_spot
		Mind.SNIFF:
			goal = _sniff_at.global_position - (_sniff_at.global_position - global_position).normalized() * 0.45
		Mind.SCATTER:
			var away := global_position - _flee_from
			away.y = 0.0
			goal = global_position + (away.normalized() if away.length() > 0.01 else Vector3.BACK) * 3.0
			pace = 1.4
	var seek := Vector3(goal.x - global_position.x, 0.0, goal.z - global_position.z)
	var far := seek.length()
	var want := seek.normalized() * clampf(far * 2.2, 0.0, sprint_speed) * pace if far > 0.25 else Vector3.ZERO
	# (well behind, it comes at a bound)
	if flat_to.length() > 4.0 and mind != Mind.SCATTER:
		want = want.normalized() * sprint_speed
	# Kept apart from the others and from him
	want += squad.apart(self) * 6.0
	if flat_to.length() < 0.75:
		want -= flat_to.normalized() * (0.75 - flat_to.length()) * 6.0
	# Going his way, a little
	if mind == Mind.FOLLOW:
		want += Vector3(hero.velocity.x, 0.0, hero.velocity.z) * 0.25
	# Sniffing, it noses about where it stands; sitting, it sits
	if mind == Mind.SNIFF and far < 0.5:
		want = Vector3(sin(Time.get_ticks_msec() * 0.004 + _seed), 0.0, cos(Time.get_ticks_msec() * 0.003 + _seed)) * 0.25
	var sitting := mind == Mind.SIT and far < 0.6
	if sitting:
		want = Vector3.ZERO
	sit_progress = move_toward(sit_progress, 1.0 if sitting else 0.0, delta * (0.9 if sitting else 3.0))
	want = want.limit_length(sprint_speed * (1.4 if mind == Mind.SCATTER else 1.0))

	var on_floor := is_on_floor()
	var flat := Vector3(velocity.x, 0.0, velocity.z).move_toward(want, (28.0 if on_floor else 6.0) * delta)
	var vy := velocity.y
	if on_floor:
		air_time = 0.0
		vy = -0.1
		# Hopping up after him onto something low, or over what is in its way
		var climb := to_hero.y > 0.5 and to_hero.y < 2.2 and flat_to.length() < 3.0 and hero.is_on_floor()
		if climb or (want.length() > 1.0 and _blocked(want)):
			vy = 6.2 if climb else 5.0
			if climb:
				flat = flat_to.normalized() * clampf(flat_to.length() * 1.6, 1.5, 4.5)
			jumped.emit()
	else:
		air_time += delta
		vy -= 20.0 * delta
		_fall_speed = -vy
	velocity = Vector3(flat.x, vy, flat.z)
	is_sprinting = flat.length() > run_speed * 0.85
	if flat.length() > 0.15:
		rotation.y = lerp_angle(rotation.y, atan2(flat.x, flat.z), 1.0 - exp(-10.0 * delta))
	elif mind == Mind.SIT or mind == Mind.FOLLOW:
		# (still, it turns to look at him)
		rotation.y = lerp_angle(rotation.y, atan2(flat_to.x, flat_to.z), 1.0 - exp(-3.0 * delta))
	move_and_slide()
	if is_on_floor() and not _was_floor:
		landed.emit(_fall_speed)
	_was_floor = is_on_floor()


## Sent running from `from` for a while.
func _scatter(from: Vector3, seconds: float) -> void:
	_flee_from = from
	if mind != Mind.SCATTER:
		_go(Mind.SCATTER, seconds + randf() * 0.6)


func _go(to: Mind, seconds: float) -> void:
	mind = to
	_mind_t = seconds


## Whether something solid is close in front of it, low enough to hop over.
func _blocked(way: Vector3) -> bool:
	var from := global_position + Vector3.UP * 0.2
	var query := PhysicsRayQueryParameters3D.create(from, from + way.normalized() * 0.45, 1)
	query.exclude = [get_rid()]
	return not get_world_3d().direct_space_state.intersect_ray(query).is_empty()
