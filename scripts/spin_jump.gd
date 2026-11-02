class_name SpinJump
extends Node
## A child of the Player: the spin jump, as in Mario Sunshine (the user, 2026-11-01: "when you twirl the stick and
## start spinning, the spin should be faster, and if you jump in this mode you should do a spin jump"). Jump while
## spinning (whipping the stick round: the Player's own spin, faster in raccoon.tscn): he goes up higher than a jump,
## twirling round and round (RaccoonRig reads `twirling`), and comes down slowly, still twirling, till he lands.
##
## The Player takes no jump while spinning, so the jump is caught here, before the Player moves each step.

## How much higher than a jump, and how fast he may fall twirling down.
@export var height := 2.6
@export var fall := 1.8

var twirling := false
## How fast he turns all the way up and down (rad/s): as fast as he was spinning on the ground when he jumped, and no
## faster or slower in the air (the user, 2026-11-02: "you shouldnt be able to spin faster in the air while doing a spin
## jump" / "or slower").
var _turn := 0.0
var _player: Player
var _since := 0.0


func _enter_tree() -> void:
	process_physics_priority = -5


func _ready() -> void:
	_player = get_parent() as Player


func _physics_process(delta: float) -> void:
	_since += delta
	if twirling:
		if _player.is_on_floor() and _since > 0.2 or _player.state != Player.State.FREE:
			twirling = false
		else:
			if _player.velocity.y < -fall:
				_player.velocity.y = -fall
			# (held at it: the Player would let it die away, and the stick would turn him then)
			_player._spin_speed = _turn
		return
	if not _player.takes_input or Player.input_blocked or _player._jump_buffer <= 0.0:
		return
	if not (_player.is_spinning and _player.is_on_floor() and _player.state == Player.State.FREE):
		return
	_player._jump_buffer = 0.0
	_turn = signf(_player._spin_speed if absf(_player._spin_speed) > 0.1 else 1.0) * maxf(absf(_player._spin_speed), 10.0)
	_player.is_spinning = false
	_player.velocity.y = 2.0 * _player.jump_height / _player.time_to_apex * sqrt(height)
	twirling = true
	_since = 0.0
	_player.jumped.emit()
