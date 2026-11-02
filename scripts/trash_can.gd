class_name TrashCan
extends RigidBody3D
## A metal trash can to knock over (the user, 2026-11-01: "trash cans to knock over"): his tail spin sends it
## flying, running into it shoves it; the first time it goes over, its lid comes off and Crumbs spill out.

signal spilled(at: Array[Vector3])

## How many Crumbs it holds.
@export var holds := 3

var tipped := false
var _lid: RigidBody3D


static func make(material: Material) -> TrashCan:
	var can := TrashCan.new()
	can.set_meta(&"material", material)
	return can


func _ready() -> void:
	add_to_group(&"tail_hittable")
	add_to_group(&"interest")
	mass = 3.0
	collision_layer = 1
	collision_mask = 1 | 2
	var shape := CylinderShape3D.new()
	shape.radius = 0.32
	shape.height = 0.85
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.position.y = 0.425
	add_child(collider)
	var body: Node3D = (load("res://models/trashcan.glb") as PackedScene).instantiate()
	add_child(body)
	_lid = RigidBody3D.new()
	_lid.mass = 0.6
	_lid.freeze = true
	_lid.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	var lid_shape := CylinderShape3D.new()
	lid_shape.radius = 0.36
	lid_shape.height = 0.08
	var lid_collider := CollisionShape3D.new()
	lid_collider.shape = lid_shape
	lid_collider.position.y = 0.04
	_lid.add_child(lid_collider)
	_lid.add_child((load("res://models/trashlid.glb") as PackedScene).instantiate())
	_lid.position.y = 0.85
	add_child(_lid)
	var material: Material = get_meta(&"material", null)
	if material:
		for mesh: MeshInstance3D in find_children("*", "MeshInstance3D", true, false):
			mesh.material_override = material


## Hit by his tail: sent flying, tumbling.
func tail_hit(_from: Vector3, push: Vector3) -> void:
	apply_central_impulse(push * mass * 0.9)
	apply_torque_impulse(Vector3(push.z, 0.0, -push.x).normalized() * mass * 1.6)


func _physics_process(_delta: float) -> void:
	if not tipped and global_basis.y.dot(Vector3.UP) < 0.45:
		_tip()


func _tip() -> void:
	tipped = true
	remove_from_group(&"interest")
	# The lid comes off, tumbling away on its own
	var at := _lid.global_transform
	remove_child(_lid)
	get_parent().add_child(_lid)
	_lid.global_transform = at
	_lid.freeze = false
	_lid.apply_central_impulse((global_basis.y + Vector3.UP * 0.6) * 2.0)
	# Crumbs spill out of its mouth in a little fan
	var mouth := global_transform * Vector3(0.0, 0.85, 0.0)
	var out := Vector3(global_basis.y.x, 0.0, global_basis.y.z).normalized()
	var side := out.cross(Vector3.UP)
	var spots: Array[Vector3] = []
	for k in holds:
		var spread := (k - (holds - 1) * 0.5) * 0.55
		spots.append(Vector3(mouth.x, 0.05, mouth.z) + out * (0.7 + 0.25 * (k % 2)) + side * spread)
	spilled.emit(spots)
