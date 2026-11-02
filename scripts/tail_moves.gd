class_name TailMoves
extends Node
## The raccoon's tail moves, a child of the Player named "TailMoves" (RaccoonRig finds
## it there and poses them):
##
## - Whip (the tail button on the ground): a lash round past his left side and out
##   in front, hitting what is ahead of him.
## - Spin (the tail button in the air): once round with the tail flung out, a little
##   lift, hitting everything around him.
## - Twirl (jump held while falling): the tail whirled over his head, and he comes down slowly.
##
## Anything in the group `tail_hittable` with a `tail_hit(from: Vector3, push: Vector3)`
## method is hit; a RigidBody3D in it without one is knocked away.

signal struck(what: Node)

@export var whip_time := 0.42
@export var whip_reach := 1.55
## The whip hits in a cone this wide (radians either side of straight ahead).
@export var whip_cone := 1.1
@export var spin_time := 0.5
@export var spin_reach := 1.35
@export var spin_lift := 2.2
## How fast he may fall while twirling.
@export var glide_fall := 1.25
## He has to have been off the ground this long before a held jump twirls.
@export var glide_after := 0.22

## How far through each move he is (1: not doing it).
var whip := 1.0
var spin := 1.0
var gliding := false

var _player: Player
var _struck := {}
var _airborne := 0.0
var _spun_this_jump := false
var _pressed := false


func _ready() -> void:
	_player = get_parent() as Player
	if not InputMap.has_action(&"tail"):
		InputMap.add_action(&"tail")
		for key: Key in [KEY_E, KEY_K]:
			var press := InputEventKey.new()
			press.physical_keycode = key
			InputMap.action_add_event(&"tail", press)
		var pad := InputEventJoypadButton.new()
		pad.button_index = JOY_BUTTON_X
		InputMap.action_add_event(&"tail", pad)
		var mouse := InputEventMouseButton.new()
		mouse.button_index = MOUSE_BUTTON_LEFT
		InputMap.action_add_event(&"tail", mouse)


## For the on-screen button (and tests): as if the tail button were pressed.
func press() -> void:
	_pressed = true


func _listening() -> bool:
	return _player.takes_input and not Player.input_blocked


func _physics_process(delta: float) -> void:
	if _player == null:
		return
	var free := _player.state == Player.State.FREE and not _player.is_limp
	var grounded := _player.is_on_floor()
	_airborne = 0.0 if grounded else _airborne + delta
	if grounded:
		_spun_this_jump = false

	if (_pressed or (_listening() and Input.is_action_just_pressed(&"tail"))) and free and whip >= 1.0 and spin >= 1.0:
		if grounded:
			whip = 0.0
		elif not _spun_this_jump:
			spin = 0.0
			_spun_this_jump = true
			_player.velocity.y = maxf(_player.velocity.y, spin_lift)
		_struck.clear()
	_pressed = false

	if whip < 1.0:
		whip = minf(whip + delta / whip_time, 1.0)
		if whip > 0.25 and whip < 0.7:
			_strike(whip_reach, whip_cone)
	if spin < 1.0:
		spin = minf(spin + delta / spin_time, 1.0)
		if spin > 0.05 and spin < 0.9:
			_strike(spin_reach, PI)

	# The twirl: jump held on the way down.
	var holding: bool = _player._is_jump_held()
	gliding = free and not grounded and holding and _airborne > glide_after and _player.velocity.y < 0.0 and not _player.is_diving and spin >= 1.0
	if gliding:
		_player.velocity.y = maxf(_player.velocity.y, -glide_fall)


func _strike(reach: float, cone: float) -> void:
	var from := _player.global_position + Vector3.UP * 0.4
	var ahead := Vector3(sin(_player.facing_yaw), 0.0, cos(_player.facing_yaw))
	for node in get_tree().get_nodes_in_group(&"tail_hittable"):
		if _struck.has(node) or not node is Node3D:
			continue
		var to: Vector3 = (node as Node3D).global_position - from
		var flat := Vector3(to.x, 0.0, to.z)
		if flat.length() > reach or absf(to.y) > 1.3:
			continue
		if cone < PI and flat.length() > 0.2 and ahead.angle_to(flat) > cone:
			continue
		_struck[node] = true
		var push := (flat.normalized() if flat.length() > 0.01 else ahead) * 6.0 + Vector3.UP * 2.5
		if node.has_method(&"tail_hit"):
			node.tail_hit(from, push)
		elif node is RigidBody3D:
			(node as RigidBody3D).apply_central_impulse(push * (node as RigidBody3D).mass)
		struck.emit(node)
