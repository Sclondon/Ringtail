class_name Dumpster
extends StaticBody3D
## A dumpster to jump into (the user, 2026-11-02: "there should be dumpsters to jump into"): models/dumpster.glb
## (tools/build_dumpster.py), solid walls and floor, the right lid shut (stand on it), the left one thrown open so
## he drops in over the rim; Crumbs lie on its floor (World puts them there: `inside()`). Climbable, so he scurries
## up its side to get in and out.

## Its size (build_dumpster.py's LONG, DEEP, RIM, FLOOR).
const LONG := 1.8
const DEEP := 1.1
const RIM := 1.15
const FLOOR := 0.2
const WALL := 0.08
## How many Crumbs lie in it.
const HOLDS := 4


func _ready() -> void:
	add_to_group(&"climbable")
	add_to_group(&"interest")
	collision_layer = 1
	add_child((load("res://models/dumpster.glb") as PackedScene).instantiate())
	Toon.apply(self)
	var hx := LONG * 0.5
	var hz := DEEP * 0.5
	var high := RIM - FLOOR
	_box(Vector3(0.0, FLOOR * 0.5 + 0.03, 0.0), Vector3(LONG, FLOOR + 0.06, DEEP))
	for z in [-hz + WALL * 0.5, hz - WALL * 0.5]:
		_box(Vector3(0.0, FLOOR + high * 0.5, z), Vector3(LONG, high, WALL))
	for x in [-hx + WALL * 0.5, hx - WALL * 0.5]:
		_box(Vector3(x, FLOOR + high * 0.5, 0.0), Vector3(WALL, high, DEEP))
	# (the shut lid over the right half; the open one hangs down the back, outside)
	_box(Vector3(hx * 0.5, RIM + 0.05, 0.0), Vector3(hx, 0.06, DEEP + 0.08))
	_box(Vector3(-hx * 0.5, RIM - 0.55, -hz - 0.09), Vector3(hx, 1.1, 0.06))


func _box(at: Vector3, size: Vector3) -> void:
	var shape := BoxShape3D.new()
	shape.size = size
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.position = at
	add_child(collider)


## Where its Crumbs lie, in the world: along the floor under the open lid and under the shut one.
func inside() -> Array[Vector3]:
	var spots: Array[Vector3] = []
	for k in HOLDS:
		var along := lerpf(-LONG * 0.35, LONG * 0.35, float(k) / float(HOLDS - 1))
		spots.append(global_transform * Vector3(along, FLOOR + 0.06, 0.12 * (1 - 2 * (k % 2))))
	return spots
