class_name WaterLeap
extends Node
## A child of the Player: a jump out of the water is a big leap clear of it (the user,
## 2026-11-01: "you dont jump nearly high enough in water"). The controller's own heave
## out is 0.8 of a jump, made for the boy, who floats higher in the water than he does.

## How high the leap goes, as a share of a jump from the ground.
@export var height := 2.7

var _player: Player
var _was_swimming := false


func _ready() -> void:
	_player = get_parent() as Player
	# (the jump is made, and the signal sent, while the Player is still in the water this frame)
	_player.jumped.connect(func() -> void:
		if _was_swimming:
			var rise := 2.0 * _player.jump_height / _player.time_to_apex
			_player.velocity.y = rise * sqrt(height))


func _physics_process(_delta: float) -> void:
	# (before the Player moves: what he was doing when this frame began)
	_was_swimming = _player.state == Player.State.SWIM


func _enter_tree() -> void:
	process_physics_priority = -5
