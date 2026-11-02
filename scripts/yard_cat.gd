class_name YardCat
extends CharacterBody3D
## A yard cat (the enemy; each its own look, FurLook.CAT_LOOKS: placeholders), built and animated as the raccoon is: his model
## kit and his rig (CatRig, a RaccoonRig, on all fours whenever it is on the ground).
##
## What it does (the user, 2026-11-02: "the cats should have more complex behaviour, stalking around climbing houses and
## walking along wires (so they are better at chasing)"; every number and the order of things are Claude's picks):
## - About its patch: it wanders, sits and washes, and now and then jumps up onto a wall, a fence or a low roof near
##   home and sits there a while.
## - Seeing him (Hazards.unseen: not in the grove, not down in tall grass) it stalks him low, stopping and starting,
##   then crouches, wiggles its rump and pounces. A pounce that reaches him hurts him.
## - Missed, or when he runs or goes up out of reach, it gives chase, a little slower than he runs: it leaps up any
##   ledge a wall's height (CAT_JUMP), leaps gaps from roof to roof, scrabbles up whatever he can climb (drainpipes,
##   trees, poles: the group `climbable`), and walks the wires as he does, jumping onto one from a roof or climbing a
##   pole to it, to cut him off.
## - It gives up after CHASE_FOR seconds, past TERRITORY metres from home, or once it has lost him for a few seconds,
##   and goes home, paying him no mind a while.
## - His tail spin (`tail_hit`) knocks it tumbling, and it runs off for good, with a "beaten" signal.
##
## The rig takes this body as it would a Player: `velocity`, `is_on_floor()`, the speeds, `is_ducking` (low,
## stalking), `sit_progress`, `tightrope`, and `jumped` and `landed` for its leaps; `climbing_npc` while it climbs.

signal beaten(cat: YardCat)
# (for the rig: the leap off the ground, and coming down)
signal jumped
signal landed(impact_speed: float)
signal respawned

enum Mode { WANDER, STALK, CROUCH, POUNCE, RECOVER, DAZED, FLEE, SIT, CHASE, LEAP, CLIMB, WIRE, SEARCH, HOME }

@export var notice := 7.0
@export var pounce_from := 2.6
@export var wander_radius := 3.5
@export var pounce_speed := 6.0
## How big it is beside him (the raccoon's skeleton, made smaller).
@export var size := 0.85

## How high it can leap up onto something, how far across a gap, how fast it climbs and walks a wire (m, m/s).
const CAT_JUMP := 2.3
const CAT_GAP := 3.6
const CLIMB_SPEED := 1.8
const WIRE_SPEED := 1.5
## How long it chases, how far from home it goes, how long it looks for him once he is lost, how long it then pays
## him no mind.
const CHASE_FOR := 14.0
const TERRITORY := 20.0
const LOST_FOR := 2.5
const COOL_FOR := 6.0
## How far round it looks for something to climb.
const CLIMB_LOOK := 9.0

# (slower than the raccoon, so he can get away from it and round it)
var walk_speed := 0.9
var run_speed := 3.3
var is_pushing := false
var is_ducking := false
var is_crawling := false
## For the rig: how far sat down (0..1), and on a wire (how far into balancing, how far off its line).
var sit_progress := 0.0
var tightrope := 0.0
var tightrope_aside := 0.0

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
## Chasing: how long, where he was last seen and how long ago, and how long it pays him no mind after giving up.
var _chase_t := 0.0
var _seen_at := Vector3.ZERO
var _unseen_t := 0.0
var _cool := 0.0
## What it does after a leap, and whether it was making for a wire.
var _after := Mode.CHASE
var _leap_wire: Tightrope
## Climbing: the column it goes up (a point inside the thing climbed, on its line), which way is out from it, how high
## it is going, and whether it is on the way down.
var _climb_core := Vector3.ZERO
var _climb_out := Vector3.BACK
var _climb_to := 0.0
var _climb_down := false
var _climb_foot := Vector3.ZERO
var _climb_started := false
## On a wire: which, how far along, and where it is making for along it.
var _wire: Tightrope
var _wire_d := 0.0
## Thinking about how to get at him, a few times a second; stuck against something, how long.
var _think := 0.0
var _stuck := 0.0
## Sitting: how long, and whether washing.
var _sit_for := 0.0
var _washing := false


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
	_cool = maxf(_cool - delta, 0.0)
	var grounded := is_on_floor()
	var held := mode == Mode.CLIMB and _climb_started or mode == Mode.WIRE
	if not grounded and not held:
		velocity.y -= _gravity * delta
	var to_target := Vector3.ZERO
	var near := INF
	if target:
		to_target = target.global_position - global_position
		near = Vector2(to_target.x, to_target.z).length()
	# (it sees up onto roofs and down off them too; never into the grove or tall grass)
	var sees := target != null and _cool <= 0.0 and near < notice and to_target.y > -4.0 and to_target.y < 8.0 \
			and not Hazards.unseen(target)
	if sees:
		_seen_at = target.global_position
		_unseen_t = 0.0
	else:
		_unseen_t += delta
	is_ducking = false
	rig.wiggle = 0.0
	var sitting := false
	match mode:
		Mode.WANDER:
			if global_position.distance_to(_goal) < 0.4 or _mode_t > 4.0:
				_mode_t = 0.0
				_idle_choice()
			_walk_to(_goal, walk_speed, delta)
			if sees and grounded:
				_go(Mode.STALK)
		Mode.SIT:
			# Sat (on the ground, or up on a wall or a roof), now and then washing
			sitting = true
			_walk_to(global_position, 0.0, delta)
			if sees:
				_go(Mode.STALK)
			elif _mode_t > _sit_for:
				_goal = home
				_go(Mode.WANDER)
		Mode.STALK:
			# Low, creeping at him, stopping still now and then; if he runs, or is up out of reach, after him
			is_ducking = true
			var pause := fmod(_mode_t, 2.0) > 1.4
			_walk_to(target.global_position, 0.0 if pause else walk_speed * 1.3, delta)
			if pause:
				_face(to_target, delta * 6.0)
			if not sees:
				_go(Mode.WANDER)
			elif to_target.y > 0.8 or to_target.y < -1.5 or Vector2(target.velocity.x, target.velocity.z).length() > 2.6:
				_start_chase()
			elif near < pounce_from and grounded:
				_go(Mode.CROUCH)
		Mode.CROUCH:
			is_ducking = true
			_walk_to(global_position, 0.0, delta)
			_face(to_target, delta * 8.0)
			# (stalking, it takes its time; chasing, a quick gather and away)
			var gather := 0.85 if _chase_t <= 0.0 else 0.35
			rig.wiggle = smoothstep(0.1, 0.5, _mode_t / gather * 0.85)
			if _mode_t > gather:
				_pounce(to_target)
		Mode.POUNCE:
			_hurt_check()
			if grounded and _mode_t > 0.2:
				velocity = Vector3.ZERO
				_go(Mode.RECOVER)
		Mode.RECOVER:
			_walk_to(global_position, 0.0, delta)
			_face(to_target, delta * 4.0)
			if _mode_t > 0.5:
				if sees:
					_start_chase()
				else:
					_go(Mode.WANDER)
		Mode.CHASE:
			_chase(delta, sees, to_target, near, grounded)
		Mode.LEAP:
			if _leap_wire and _leap_wire.distance_to(global_position) < 0.4 and velocity.y <= 0.0:
				_onto_wire(_leap_wire)
			elif grounded and _mode_t > 0.15:
				_leap_wire = null
				velocity.x = 0.0
				velocity.z = 0.0
				_go(_after)
			elif _mode_t > 3.0:
				_go(Mode.HOME)
		Mode.CLIMB:
			_climbing(delta, sees, to_target)
		Mode.WIRE:
			_walk_wire(delta, sees, to_target)
		Mode.SEARCH:
			# Lost him: to where he was last seen, a look about, then home
			_walk_to(_seen_at, run_speed * 0.6, delta)
			if sees:
				_go(Mode.CHASE)
			elif _mode_t > LOST_FOR + 1.5:
				_give_up()
		Mode.HOME:
			_walk_to(home, walk_speed * 1.6, delta)
			_unstick(home - global_position, delta)
			if Vector2(home.x - global_position.x, home.z - global_position.z).length() < 0.8 or _mode_t > 25.0:
				_goal = home
				_go(Mode.WANDER)
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
	sit_progress = move_toward(sit_progress, 1.0 if sitting else 0.0, delta * 2.5)
	rig.groom = move_toward(rig.groom, 1.0 if sitting and _washing and sit_progress > 0.9 else 0.0, delta * 3.0)
	tightrope = move_toward(tightrope, 1.0 if mode == Mode.WIRE else 0.0, delta * 4.0)
	if mode == Mode.CLIMB and _climb_started or mode == Mode.WIRE:
		# (moved along what it holds, nothing pushing it)
		return
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


# --- About its patch ---

## Done going somewhere about its patch: somewhere else, or sit a while (and wash), or up onto a wall or roof by home.
func _idle_choice() -> void:
	var roll := randf()
	if roll < 0.3:
		_sit(randf_range(4.0, 9.0))
		return
	if roll < 0.55 and global_position.distance_to(home) < wander_radius * 2.0:
		var a := randf() * TAU
		var top := _ledge_toward(Vector3(cos(a), 0.0, sin(a)))
		if top != Vector3.INF and top.y - home.y < CAT_JUMP + 1.0:
			_leap_to(top, Mode.SIT)
			_sit_for = randf_range(5.0, 11.0)
			_washing = randf() < 0.5
			return
	_goal = home + Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0)) * wander_radius


func _sit(seconds: float) -> void:
	_sit_for = seconds
	_washing = randf() < 0.6
	_go(Mode.SIT)


# --- The chase ---

func _start_chase() -> void:
	_chase_t = 0.0
	_think = 0.0
	_go(Mode.CHASE)


func _chase(delta: float, sees: bool, to_target: Vector3, near: float, grounded: bool) -> void:
	_chase_t += delta
	if _chase_t > CHASE_FOR or global_position.distance_to(home) > TERRITORY or (target and Hazards.unseen(target)):
		_give_up()
		return
	if _unseen_t > LOST_FOR:
		_go(Mode.SEARCH)
		return
	var goal := target.global_position if sees else _seen_at
	var flat := Vector3(goal.x - global_position.x, 0.0, goal.z - global_position.z)
	var way := flat.normalized() if flat.length() > 0.05 else -global_basis.z
	var rise := goal.y - global_position.y
	_walk_to(goal, run_speed, delta)
	if not grounded:
		return
	# Close, and level with him: a quick gather, and pounce
	if sees and near < 1.7 and absf(rise) < 0.6:
		_go(Mode.CROUCH)
		return
	_think -= delta
	if _think > 0.0:
		_unstick(way, delta)
		return
	_think = 0.25
	# He is on a wire: onto it, from here if it is in reach, else up a pole to it
	var on_wire := target.tightrope_on as Tightrope if sees and target.tightrope > 0.0 else null
	if on_wire:
		var at := on_wire.point_near(global_position)
		var off := at - global_position
		if Vector2(off.x, off.z).length() < CAT_GAP and off.y > -1.5 and off.y < CAT_JUMP:
			_leap_wire = on_wire
			_leap_to(at, Mode.CHASE)
			return
		if _climb_after(at.y, at):
			return
	# He is up out of reach: a ledge to leap onto, else something to climb
	if rise > 0.8:
		var top := _ledge_toward(way)
		if top != Vector3.INF:
			_leap_to(top, Mode.CHASE)
			return
		if near < 4.0 or _stuck > 0.5:
			if _climb_after(goal.y, goal):
				return
	# Running at the edge of a roof with him further on: across the gap
	if near > 1.5 and _edge_ahead(way):
		var over := _gap_toward(way, goal)
		if over != Vector3.INF:
			_leap_to(over, Mode.CHASE)
			return
	_unstick(way, delta)


## Pressing against something and not getting on: leap up it if it can, else climb it.
func _unstick(way: Vector3, delta: float) -> void:
	var going := Vector2(velocity.x, velocity.z).length()
	_stuck = _stuck + delta if going < 0.4 and is_on_floor() else 0.0
	if _stuck < 0.7:
		return
	_stuck = 0.0
	var top := _ledge_toward(way.normalized())
	if top != Vector3.INF:
		_leap_to(top, mode if mode != Mode.LEAP else Mode.CHASE)
	elif mode == Mode.CHASE and target:
		_climb_after(target.global_position.y, target.global_position)


func _give_up() -> void:
	_chase_t = 0.0
	_cool = COOL_FOR
	_go(Mode.HOME)


func _pounce(to_target: Vector3) -> void:
	var flat := Vector3(to_target.x, 0.0, to_target.z)
	var speed := clampf(flat.length() / 0.55, 2.0, pounce_speed)
	velocity = flat.normalized() * speed + Vector3.UP * (5.0 + clampf(to_target.y, 0.0, 1.0) * 3.0)
	_hurt_done = false
	_go(Mode.POUNCE)
	jumped.emit()


func _hurt_check() -> void:
	if not _hurt_done and target and global_position.distance_to(target.global_position + Vector3.UP * 0.3) < 0.75:
		_hurt_done = true
		var game := get_tree().get_first_node_in_group(&"game")
		if game:
			game.hurt(global_position)


# --- Leaping ---

## Off the ground in an arc that comes down on `point`, then `after`.
func _leap_to(point: Vector3, after: Mode) -> void:
	var from := global_position
	var apex := maxf(point.y, from.y) + 0.45
	var up := sqrt(2.0 * _gravity * maxf(apex - from.y, 0.05))
	var down := sqrt(2.0 * _gravity * maxf(apex - point.y, 0.05))
	var time := up / _gravity + down / _gravity
	var flat := Vector3(point.x - from.x, 0.0, point.z - from.z)
	velocity = flat / maxf(time, 0.1) + Vector3.UP * up
	_face(flat, 1.0)
	_after = after
	_go(Mode.LEAP)
	jumped.emit()


## The top of something a leap's height up, a little way along `way` (Vector3.INF if none).
func _ledge_toward(way: Vector3) -> Vector3:
	var space := get_world_3d().direct_space_state
	var foot := global_position
	for reach: float in [0.5, 0.8, 1.1, 1.5]:
		var over := foot + way * reach
		var query := PhysicsRayQueryParameters3D.create(over + Vector3.UP * (CAT_JUMP + 0.4), Vector3(over.x, foot.y + 0.3, over.z), 1)
		query.exclude = [get_rid()]
		var hit := space.intersect_ray(query)
		if hit.is_empty() or (hit.normal as Vector3).y < 0.7:
			continue
		var top: Vector3 = hit.position
		if top.y - foot.y < 0.35 or top.y - foot.y > CAT_JUMP:
			continue
		# (room on it for a cat, and not inside something: open over the top)
		var room := PhysicsRayQueryParameters3D.create(top + Vector3.UP * 0.05, top + Vector3.UP * 0.55, 1)
		room.exclude = [get_rid()]
		if not space.intersect_ray(room).is_empty():
			continue
		return top
	return Vector3.INF


## Whether the ground runs out just ahead along `way` (an edge, a drop of more than a metre).
func _edge_ahead(way: Vector3) -> bool:
	var over := global_position + way * 0.6 + Vector3.UP * 0.3
	var query := PhysicsRayQueryParameters3D.create(over, over + Vector3.DOWN * 1.4, 1)
	query.exclude = [get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


## Across a gap along `way` towards `goal`: somewhere to land a leap away, not much lower or higher than here.
func _gap_toward(way: Vector3, goal: Vector3) -> Vector3:
	var space := get_world_3d().direct_space_state
	var best := Vector3.INF
	var reach := 1.4
	while reach <= CAT_GAP:
		var over := global_position + way * reach
		var query := PhysicsRayQueryParameters3D.create(over + Vector3.UP * 1.5, over + Vector3.DOWN * 2.5, 1)
		query.exclude = [get_rid()]
		var hit := space.intersect_ray(query)
		if not hit.is_empty() and (hit.normal as Vector3).y > 0.7:
			var y: float = (hit.position as Vector3).y
			if y - global_position.y < 1.0 and y - global_position.y > -2.0 and absf(y - goal.y) < 1.5:
				best = hit.position
				break
		reach += 0.4
	return best


# --- Climbing (drainpipes, trees, poles, fences: whatever he can climb) ---

## Off to climb the climbable thing nearest a way to `toward`, up to `height`: true if it found one.
func _climb_after(height: float, toward: Vector3) -> bool:
	var space := get_world_3d().direct_space_state
	var best_score := INF
	var found := false
	for high: float in [0.4, 1.2]:
		var from := global_position + Vector3.UP * high
		for k in 24:
			var a := TAU * k / 24.0
			var query := PhysicsRayQueryParameters3D.create(from, from + Vector3(cos(a), 0.0, sin(a)) * CLIMB_LOOK, 1)
			query.exclude = [get_rid()]
			var hit := space.intersect_ray(query)
			if hit.is_empty():
				continue
			var body: Node = hit.collider
			if not (body.is_in_group(&"climbable") or (body.get_parent() and body.get_parent().is_in_group(&"climbable"))):
				continue
			var at: Vector3 = hit.position
			var normal: Vector3 = hit.normal
			normal.y = 0.0
			if normal.length() < 0.3:
				continue
			normal = normal.normalized()
			var score := at.distance_to(global_position) + Vector2(at.x - toward.x, at.z - toward.z).length() * 0.8
			if score < best_score:
				best_score = score
				found = true
				_climb_out = normal
				_climb_core = at - normal * 0.3
				_climb_foot = at + normal * 0.3
	if not found:
		return false
	_climb_core.y = global_position.y
	_climb_foot.y = global_position.y
	_climb_to = height + 0.1
	_climb_down = false
	_climb_started = false
	_go(Mode.CLIMB)
	return true


## Where the surface it climbs is at `y`, a paw's breadth out from it (Vector3.INF where there is none: over the top).
func _surface_at(y: float) -> Vector3:
	var core := Vector3(_climb_core.x, y, _climb_core.z)
	var query := PhysicsRayQueryParameters3D.create(core + _climb_out * 2.0, core, 1)
	query.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return Vector3.INF
	return (hit.position as Vector3) + _climb_out * 0.2


func _climbing(delta: float, sees: bool, to_target: Vector3) -> void:
	if not _climb_started:
		# To its foot first
		_walk_to(_climb_foot, run_speed, delta)
		var flat := Vector2(_climb_foot.x - global_position.x, _climb_foot.z - global_position.z)
		if flat.length() < 0.35 or (_mode_t > 1.0 and Vector2(velocity.x, velocity.z).length() < 0.3):
			_climb_started = true
			collision_mask = 0
			velocity = Vector3.ZERO
			rig.climbing_npc = true
		elif _mode_t > 4.0:
			_go(Mode.CHASE)
		return
	rotation.y = atan2(-_climb_out.x, -_climb_out.z)
	if _climb_down:
		var down := CLIMB_SPEED * 1.2 * delta
		var query := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 0.1, global_position + Vector3.DOWN * 0.5, 1)
		query.exclude = [get_rid()]
		var ground := get_world_3d().direct_space_state.intersect_ray(query)
		if not ground.is_empty() and global_position.y - (ground.position as Vector3).y < down + 0.05:
			global_position.y = (ground.position as Vector3).y
			_end_climb()
			_give_up()
			return
		var on := _surface_at(global_position.y - down)
		global_position = Vector3(on.x, global_position.y - down, on.z) if on != Vector3.INF else global_position + Vector3.DOWN * down
		velocity = Vector3(0.0, -CLIMB_SPEED, 0.0)
		return
	# Lost him, or he is long gone: back down
	if (not sees and _unseen_t > LOST_FOR) or (target and Hazards.unseen(target)) or _mode_t > 12.0:
		_climb_down = true
		return
	# Up level with him, and he is close: leap at him
	if sees and global_position.y >= target.global_position.y + 0.1 and Vector2(to_target.x, to_target.z).length() < 2.6 \
			and target.is_on_floor() and target.tightrope <= 0.0 and _clear_to(target.global_position + Vector3.UP * 0.3):
		_end_climb()
		_leap_to(target.global_position, Mode.CHASE)
		_hurt_done = false
		return
	var up := CLIMB_SPEED * delta
	var next := _surface_at(global_position.y + up + 0.35)
	if next == Vector3.INF or global_position.y >= _climb_to:
		_over_the_top()
		return
	global_position = Vector3(next.x, global_position.y + up, next.z)
	velocity = Vector3(0.0, CLIMB_SPEED, 0.0)


## Whether nothing stands between it and `point`.
func _clear_to(point: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 0.3, point, 1)
	var skip: Array[RID] = [get_rid()]
	if target:
		skip.append(target.get_rid())
	query.exclude = skip
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


## At the top of what it climbed: onto a wire strung there, else over onto the top, else (nothing to stand on: a
## pole's tip) back down.
func _over_the_top() -> void:
	for node in get_tree().get_nodes_in_group(&"tightropes"):
		var wire := node as Tightrope
		if wire and wire.distance_to(global_position) < 1.4:
			_end_climb()
			_onto_wire(wire)
			return
	# (over the top the way it faces, else towards him, else to either side: a pipe can be climbed from its side)
	var side := _climb_out.cross(Vector3.UP)
	var ways: Array[Vector3] = [-_climb_out, side, -side]
	if target:
		var to := target.global_position - global_position
		to.y = 0.0
		if to.length() > 0.1:
			ways.insert(1, to.normalized())
	for way in ways:
		for reach: float in [0.45, 0.8]:
			var over := global_position + way * reach + Vector3.UP * 0.6
			var query := PhysicsRayQueryParameters3D.create(over, over + Vector3.DOWN * 1.2, 1)
			query.exclude = [get_rid()]
			var hit := get_world_3d().direct_space_state.intersect_ray(query)
			if not hit.is_empty() and (hit.normal as Vector3).y > 0.6 and (hit.position as Vector3).y > global_position.y - 0.4:
				_end_climb()
				global_position = (hit.position as Vector3) + Vector3.UP * 0.02
				velocity = way * 1.0
				_go(Mode.CHASE)
				return
	_climb_down = true


func _end_climb() -> void:
	_climb_started = false
	_climb_down = false
	collision_mask = 1
	rig.climbing_npc = false


# --- Walking a wire ---

func _onto_wire(wire: Tightrope) -> void:
	_wire = wire
	_wire_d = wire.distance_along(global_position)
	_leap_wire = null
	collision_mask = 0
	velocity = Vector3.ZERO
	_go(Mode.WIRE)


func _walk_wire(delta: float, sees: bool, to_target: Vector3) -> void:
	if not is_instance_valid(_wire):
		_off_wire(Vector3.ZERO)
		return
	# Along it towards him (where he is on it, or the end nearest him), balancing
	var aim := _wire.distance_along(target.global_position) if target else _wire_d
	var step := clampf(aim - _wire_d, -WIRE_SPEED * delta, WIRE_SPEED * delta)
	_wire_d += step
	var at := _wire.point_at_distance(_wire_d)
	velocity = (at - global_position) / maxf(delta, 0.001)
	global_position = at
	tightrope_aside = sin(_t * 2.3) * 0.15
	var along := _wire.line() * (signf(step) if absf(step) > 0.0001 else 1.0)
	_face(along, 1.0)
	if sees and global_position.distance_to(target.global_position) < 1.1:
		# (at him, along the wire)
		_off_wire(Vector3.ZERO)
		_pounce(to_target)
		return
	var at_end := _wire_d < 0.35 or _wire_d > _wire.span() - 0.35
	if (not sees and _unseen_t > LOST_FOR) or _mode_t > 15.0 or (at_end and absf(step) < 0.0001 and _mode_t > 0.8):
		# (nowhere further to go on it: off, down towards him or home)
		var down := (target.global_position if sees else home) - global_position
		_off_wire(Vector3(down.x, 0.0, down.z).limit_length(2.0))
		if sees:
			_go(Mode.LEAP)
		else:
			_give_up()
			_after = Mode.HOME
			_go(Mode.LEAP)


func _off_wire(push: Vector3) -> void:
	_wire = null
	collision_mask = 1
	velocity = push + Vector3.UP * 2.0
	_after = Mode.CHASE


## Hit by his tail: knocked tumbling, then off it runs.
func tail_hit(_from: Vector3, push: Vector3) -> void:
	if mode == Mode.DAZED or mode == Mode.FLEE:
		return
	if mode == Mode.CLIMB:
		_end_climb()
	_wire = null
	collision_mask = 1
	velocity = push * 1.1
	_go(Mode.DAZED)
	beaten.emit(self)
