class_name LongJump
extends Node
## A child of the Player: the long jump, as in Mario 64 (the user, 2026-11-01: "there should be a mario 64 style
## long jump as well"). Running flat out, duck (he slides) and jump: he is thrown long and low, stretched out on
## all fours (RaccoonRig's leap).
##
## The Player takes no jump while sliding, and out of a duck jumps into a back tuck, so the jump is caught here,
## before the Player moves each step.

## How fast he goes along, and up.
@export var reach := 9.5
@export var lift := 5.0
## Ducking (not yet sliding), how fast he must be going to long jump.
@export var min_speed := 4.8

var _player: Player


func _enter_tree() -> void:
	process_physics_priority = -5


func _ready() -> void:
	_player = get_parent() as Player


func _physics_process(_delta: float) -> void:
	if not _player.takes_input or Player.input_blocked or _player._jump_buffer <= 0.0:
		return
	var flat := Vector2(_player.velocity.x, _player.velocity.z).length()
	var sliding := _player.state == Player.State.SLIDE
	var ducking_fast := _player.state == Player.State.FREE and _player.is_ducking and _player.is_on_floor() and flat >= min_speed
	# (a slide is only begun flat out: raccoon.tscn slide_min_speed)
	if not (sliding or ducking_fast):
		return
	var ahead := Vector3(sin(_player.facing_yaw), 0.0, cos(_player.facing_yaw))
	_player._jump_buffer = 0.0
	_player.state = Player.State.FREE
	_player.is_ducking = false
	_player._set_height(_player.stand_height)
	_player.velocity = ahead * reach + Vector3.UP * lift
	var rig := _player.get_node_or_null(^"Rig")
	_player.jumped.emit()
	if rig and &"_leaping" in rig:
		rig._leaping = true
