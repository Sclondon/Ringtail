class_name Trampoline
extends Area3D
## The trampoline's bed: landing on it throws him high. Held jump, he goes higher still.

@export var bounce := 10.5
@export var radius := 1.3

var _bed: Node3D
var _give := 0.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = 0.3
	var collider := CollisionShape3D.new()
	collider.shape = shape
	add_child(collider)


## The bed mesh, sagging with each bounce.
func set_bed(bed: Node3D) -> void:
	_bed = bed


func _physics_process(delta: float) -> void:
	_give = move_toward(_give, 0.0, delta * 3.0)
	if _bed:
		_bed.position.y = -0.15 * sin(_give * PI)
	for body in get_overlapping_bodies():
		var player := body as Player
		if player and player.velocity.y <= 0.5 and player.state == Player.State.FREE:
			var high: bool = player._is_jump_held()
			player.velocity.y = bounce * (1.18 if high else 1.0)
			_give = 1.0
			player.jumped.emit()
