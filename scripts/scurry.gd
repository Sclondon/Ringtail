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

var held := false
var climbing := false
## The surface he is on, and which way it faces (out, level).
var surface_normal := Vector3.ZERO
var _player: Player
var _hop := 0.0


func _enter_tree() -> void:
	process_physics_priority = -5


func _ready() -> void:
	_player = get_parent() as Player
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
	var free := _player.state == Player.State.FREE and not _player.is_limp
	if not free or not held:
		climbing = false
		return
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
func _probe(from: Vector3, ahead: Vector3) -> Dictionary:
	var best := {}
	var nearest := INF
	for turn: float in [0.0, -0.35, 0.35, -0.7, 0.7]:
		var way := ahead.rotated(Vector3.UP, turn)
		var query := PhysicsRayQueryParameters3D.create(from, from + way * (reach + 0.25), 1)
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


## The stick, as a level direction in the world (as the Player reads it).
func _stick() -> Vector3:
	return _player._to_world(_player._read_move_input())


static func _flat(v: Vector3) -> Vector3:
	var level := Vector3(v.x, 0.0, v.z)
	return level.normalized() if level.length_squared() > 0.0001 else Vector3.BACK
