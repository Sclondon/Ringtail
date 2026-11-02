class_name WireBounce
extends Node
## A child of the Player: bouncing on the wires (the user, 2026-11-02: "you should be able to bounce on the wires
## and time your jumps to jump higher and higher"), after Hemlock's Tower's. Coming down on a wire throws it down
## under him (the harder he lands, the further); it springs back up, and a jump timed as it comes back up (or while
## it is still pressed down) goes higher by how far it was down and how fast it was rising. So each timed jump
## lands harder, presses it further and throws him higher, up to `most`.

## Extra speed up (m/s) for each metre the wire is pressed down, and for each m/s it is rising, when he jumps.
@export var dip_boost := 12.0
@export var rise_boost := 0.7
## How much of his landing speed goes into the wire.
@export var landing_push := 0.75
## The most a jump can be given (m/s).
@export var most := 9.0

var _player: Player


func _ready() -> void:
	_player = get_parent() as Player
	_player.landed.connect(_on_landed)
	_player.jumped.connect(_on_jumped)


func _wire_under() -> Tightrope:
	for node in get_tree().get_nodes_in_group(&"tightropes"):
		var wire := node as Tightrope
		if wire and wire.carries(_player.global_position):
			return wire
	return null


func _on_landed(impact: float) -> void:
	var wire := _wire_under()
	if wire:
		wire.kick(_player.global_position, impact * landing_push)


func _on_jumped() -> void:
	if _player.velocity.y <= 0.0:
		return
	var wire := _wire_under()
	if wire == null:
		return
	var spring := wire.spring_at(_player.global_position)
	var extra := minf(spring.x * dip_boost + maxf(spring.y, 0.0) * rise_boost, most)
	_player.velocity.y += extra
	# (pushing off, he presses it down again)
	wire.kick(_player.global_position, 1.0)
