class_name Scurry
extends Node
## A child of the Player: scurrying (the user, 2026-11-01: "a 'Scurry' button that puts you on all 4s and allows
## you to climb certain walls like telephone poles trees vines etc", on the left trigger). Held, he goes on all
## fours (RaccoonRig reads `held`). Scurrying into anything in the group `climbable` (or whose body is in it), he
## climbs it: the stick up the screen takes him up, down brings him down, across round it; at the top he hops over onto it; jump pushes
## him off backwards.
##
## Runs before the Player each step, and gives his velocity what the Player's gravity will take off again.

## How fast he climbs, and how far ahead of him (from his middle) a climbable surface is caught.
@export var climb_speed := 2.4
@export var reach := 0.5
## How tall his collider is while he scurries (Player.height_cap).
@export var low_height := 0.62
## How fast he scurries along the ground: slower than he runs (the user, 2026-11-02, "scurrying should be slower than
## running"; his run is 4.4 m/s). Player.speed_cap.
@export var scurry_speed := 3.2

var held := false
var climbing := false
## The surface he is on, and which way it faces (out, level).
var surface_normal := Vector3.ZERO
var _player: Player
var _hop := 0.0
## Which way round he goes past a limb over his head (1 to his right).
var _round_way := 1.0
## Going round one: for how long, from where, how often it has turned back.
var _round_time := 0.0
var _round_from := Vector3.ZERO
var _round_flips := 0


func _enter_tree() -> void:
	process_physics_priority = -5


func _ready() -> void:
	_player = get_parent() as Player
	# (little blue sparkles on what can be climbed, while scurry is held)
	var glints := ClimbGlints.new()
	glints.scurry = self
	add_child(glints)
	if not InputMap.has_action(&"scurry"):
		InputMap.add_action(&"scurry", 0.3)
		var key := InputEventKey.new()
		key.physical_keycode = KEY_SHIFT
		InputMap.action_add_event(&"scurry", key)
		var trigger := InputEventJoypadMotion.new()
		trigger.axis = JOY_AXIS_TRIGGER_LEFT
		trigger.axis_value = 1.0
		InputMap.action_add_event(&"scurry", trigger)


## For the on-screen button: held or let go.
var button := false


func _listening() -> bool:
	return _player.takes_input and not Player.input_blocked


func _physics_process(delta: float) -> void:
	held = button or (_listening() and Input.is_action_pressed(&"scurry"))
	_hop = maxf(_hop - delta, 0.0)
	# (on all fours he is low: his collider is held to `low_height`, so a limb he climbs under does not catch him;
	# he stands again when let go, once there is room)
	if held or climbing:
		_player.height_cap = low_height
	elif _player.height_cap < INF and _player._has_headroom(_player.stand_height):
		_player.height_cap = INF
	_player.speed_cap = scurry_speed if held else INF
	var free := _player.state == Player.State.FREE and not _player.is_limp
	if not free or not held:
		climbing = false
		return
	# (scurrying, no ledge catches: on a tree he would catch the edge of every limb he climbed past and hang from it;
	# the user, 2026-11-02, "you need to work on the ledges on the branches, it interrupts your climbing")
	if not _player.is_on_floor():
		_player._grab_cooldown = maxf(_player._grab_cooldown, 0.1)
	var ahead := Vector3(sin(_player.facing_yaw), 0.0, cos(_player.facing_yaw))
	var middle := _player.global_position + Vector3.UP * 0.45
	var hit := _probe(middle, ahead)
	var stick := _stick()
	if not climbing:
		# Into a climbable thing, pushing towards it: on to it
		if not hit.is_empty() and _hop <= 0.0 and stick.dot(-_flat(hit.normal)) > 0.5:
			climbing = true
			surface_normal = _flat(hit.normal)
		return
	if hit.is_empty():
		# (pushed out from it a little, by a limb he is passing: still on it, drawn back in)
		hit = _probe(middle, ahead, 0.7)
	# (or his middle is inside a limb where it leaves the trunk, and the rays start in it: look from a little back,
	# and higher and lower)
	for lift: float in [0.0, 0.25, -0.2]:
		if hit.is_empty():
			hit = _probe(middle - ahead * 0.4 + Vector3.UP * lift, ahead, 0.8)
	if hit.is_empty():
		# Over the top: a hop up and onto it (or off the end of whatever it was)
		climbing = false
		_hop = 0.4
		_player.velocity = -surface_normal * 2.2 + Vector3.UP * 4.2
		return
	surface_normal = _flat(hit.normal)
	if _player._jump_buffer > 0.0:
		# Jumped off backwards
		_player._jump_buffer = 0.0
		climbing = false
		_hop = 0.5
		_player.velocity = surface_normal * 4.0 + Vector3.UP * 5.0
		_player.facing_yaw = atan2(surface_normal.x, surface_normal.z)
		_player.jumped.emit()
		return
	# (on it, the stick as on a ladder: up the screen climbs, down comes down, across goes round)
	var raw: Vector2 = _player._read_move_input()
	var towards := -raw.y
	var along := raw.x
	var up := climb_speed * clampf(towards, -1.0, 1.0)
	# (a limb over his head: he goes round it, the way he was going round or else to his right, not butting into it)
	if up > 0.0 and _overhead(middle):
		if absf(along) > 0.2 and _round_flips == 0:
			_round_way = signf(along)
		along = _round_way
		up = 0.0
		# (getting nowhere round it, caught against its side: the other way; and if that is no better, he steps up
		# onto the limb, as off a ladder's top)
		_round_time += delta
		if _round_time > 0.5:
			if _player.global_position.distance_to(_round_from) < 0.15:
				_round_flips += 1
				_round_way = -_round_way
				if _round_flips >= 3 and _mount(middle):
					return
			_round_time = 0.0
			_round_from = _player.global_position
	else:
		_round_time = 0.0
		_round_flips = 0
		_round_from = _player.global_position
	# (what the Player's gravity takes off this step, given back)
	var gravity := 2.0 * _player.jump_height / (_player.time_to_apex * _player.time_to_apex)
	if up < 0.0:
		gravity *= _player.fall_gravity_scale
	var gap: float = (hit.position as Vector3).distance_to(middle + Vector3.DOWN * 0.0) - 0.28
	_player.velocity = -surface_normal * clampf(gap * 6.0, -1.0, 1.0) + surface_normal.cross(Vector3.UP) * along * 1.2 \
			+ Vector3.UP * (up + gravity * delta)
	_player.facing_yaw = atan2(-surface_normal.x, -surface_normal.z)


## The nearest climbable thing ahead of `from` within reach: a fan of rays at his middle, so a thin pole is not
## lost as he goes round it. Its normal is taken as straight out from it towards him (the faces of a pole are
## few and flat).
func _probe(from: Vector3, ahead: Vector3, further := 0.0) -> Dictionary:
	var best := {}
	var nearest := INF
	for turn: float in [0.0, -0.35, 0.35, -0.7, 0.7]:
		var way := ahead.rotated(Vector3.UP, turn)
		var query := PhysicsRayQueryParameters3D.create(from, from + way * (reach + 0.25 + further), 1)
		query.exclude = [_player.get_rid()]
		var hit := _player.get_world_3d().direct_space_state.intersect_ray(query)
		if hit.is_empty():
			continue
		var body: Node = hit.collider
		if not (body.is_in_group(&"climbable") or (body.get_parent() and body.get_parent().is_in_group(&"climbable"))):
			continue
		var gap := from.distance_to(hit.position)
		if gap < nearest:
			nearest = gap
			best = hit
			best.normal = from - (hit.position as Vector3)
	return best


## Whether something climbable (a limb) is just over his head as he climbs.
func _overhead(middle: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(middle, middle + Vector3.UP * 0.5, 1)
	query.exclude = [_player.get_rid()]
	var hit := _player.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return false
	var body: Node = hit.collider
	return body.is_in_group(&"climbable") or (body.get_parent() != null and body.get_parent().is_in_group(&"climbable"))


## Onto the top of the limb over his head (from under it): set on it just out from where he is, off the climb.
## Whether there was a top to stand on.
func _mount(middle: Vector3) -> bool:
	var space := _player.get_world_3d().direct_space_state
	for out: float in [0.15, 0.4, 0.7]:
		var above := middle + surface_normal * out + Vector3.UP * 1.6
		var query := PhysicsRayQueryParameters3D.create(above, above + Vector3.DOWN * 1.5, 1)
		query.exclude = [_player.get_rid()]
		var hit := space.intersect_ray(query)
		if hit.is_empty() or (hit.normal as Vector3).y < 0.7:
			continue
		climbing = false
		_hop = 0.4
		_round_flips = 0
		_player.global_position = (hit.position as Vector3) + Vector3.UP * 0.05
		_player.velocity = Vector3.ZERO
		return true
	return false


## The stick, as a level direction in the world (as the Player reads it).
func _stick() -> Vector3:
	return _player._to_world(_player._read_move_input())


static func _flat(v: Vector3) -> Vector3:
	var level := Vector3(v.x, 0.0, v.z)
	return level.normalized() if level.length_squared() > 0.0001 else Vector3.BACK
