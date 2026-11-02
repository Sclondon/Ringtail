class_name PointStand
extends Node
## A child of the Player: standing on one hand on the top of a pointy thing (the user, 2026-11-02: "you need to be able
## to handstand on one hand on the top of pointy things like trees and telephone poles"; Sly Cooper's point landing).
## Coming down onto a point (PointPerches: a pole's top, a tree's tip, the chimney) he catches it and balances there
## upside-down on one paw (RaccoonRig reads `on`), as he does when he scurries up a pole to its top. There: the stick
## turns him round, jump throws him up off it as from the ground, duck or scurry lets him drop. Nothing that hunts can
## get at him there (Hazards.unseen).
##
## Runs before the Player each step; while he is on a point the Player takes no input of its own (`takes_input`).

## How near a point he must come down (across the ground), and how far above it he may be, to catch it.
@export var reach := 0.6
@export var above := 1.2
## How high a jump off it goes, against a jump from the ground.
@export var lift := 1.3

## Whether he is on a point now, and which.
var on := false
var point := Vector3.INF
var _player: Player
var _scurry: Scurry
var _rest := 0.0
var _was_y := 0.0
var _jump_was := false


func _enter_tree() -> void:
	process_physics_priority = -5


func _ready() -> void:
	_player = get_parent() as Player
	_scurry = _player.get_node_or_null(^"Scurry") as Scurry


## Whether `who` is on a point (out of reach of what hunts).
static func perched(who: Node) -> bool:
	var stand := who.get_node_or_null(^"PointStand") as PointStand if who else null
	return stand != null and stand.on


func _physics_process(delta: float) -> void:
	_rest = maxf(_rest - delta, 0.0)
	if on:
		_hold(delta)
		return
	var y := _player.global_position.y
	var falling_onto := not _player.is_on_floor() and _player.velocity.y <= 0.0
	var climbing_onto := _scurry != null and _scurry.climbing
	if _rest <= 0.0 and _player.state == Player.State.FREE and (falling_onto or climbing_onto):
		var p := PointPerches.nearest(_player.global_position, reach if falling_onto else reach + 0.3)
		if p != Vector3.INF:
			# (from above, crossing its height this step or just over it; or climbing up to just under it)
			var from_above := falling_onto and _was_y >= p.y - 0.05 and y <= p.y + above
			# (from under the crossarm a pole carries just below its top: he springs on up over it)
			var up_to_it := climbing_onto and y > p.y - 1.8 and y < p.y + 0.2
			if from_above or up_to_it:
				_catch(p)
	_was_y = y


func _catch(p: Vector3) -> void:
	on = true
	point = p
	if _scurry:
		_scurry.climbing = false
	_player.takes_input = false
	_player.velocity = Vector3.ZERO
	_player.global_position = p
	_jump_was = true
	# (a little puff where his paw comes down on it)
	var dust := _player.get_node_or_null(^"CloudDust") as CloudDust
	if dust:
		for k in 6:
			var a := TAU * k / 6.0
			var out := Vector3(cos(a), 0.0, sin(a))
			dust.puff(p + out * 0.06, out * 0.7 + Vector3.UP * 0.3, 0.07)


func _hold(delta: float) -> void:
	_player.velocity = Vector3.ZERO
	_player.global_position = point
	# The stick turns him round on it (as the camera sees it)
	var stick := Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
	var touch = _player.get(&"_touch")
	if touch and (touch.move as Vector2).length_squared() > stick.length_squared():
		stick = touch.move
	if stick.length() > 0.3:
		var way: Vector3 = _player._to_world(stick)
		_player.facing_yaw = lerp_angle(_player.facing_yaw, atan2(way.x, way.z), 1.0 - exp(-4.0 * delta))
	# Jump: up off it, as from the ground (the touch button queues his jump; keys and pad read here)
	var jump := Input.is_action_pressed(&"jump")
	var pressed := (jump and not _jump_was) or _player._jump_buffer > 0.0
	_jump_was = jump
	if pressed:
		_player._jump_buffer = 0.0
		_let_go()
		_player.velocity = Vector3.UP * 2.0 * _player.jump_height / _player.time_to_apex * sqrt(lift)
		_player.jumped.emit()
		return
	if Input.is_action_just_pressed(&"duck") or (_scurry and _scurry.button) or Input.is_action_just_pressed(&"scurry"):
		# (let go: he drops off it to one side)
		_let_go()
		_player.velocity = Vector3(sin(_player.facing_yaw), 0.0, cos(_player.facing_yaw)) * 1.5


func _let_go() -> void:
	on = false
	_rest = 0.5
	_player.takes_input = true
	_player.global_position = point + Vector3.UP * 0.05
