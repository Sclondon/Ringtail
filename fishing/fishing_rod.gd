class_name FishingRod
extends RigidBody3D
## The fishing rod in his hands (fishing/fishing.glb "rod" and "rod_crank"). To the character controller's Player it
## is a long gun (group `guns`; `two_handed`), but one that says how it is held (`held_at`, which
## CharacterRig._hold_gun asks): FishingSpot sets `grip` (where his right hand is, from his right shoulder, in the
## figure's own frame) and `point` (the way the rod points), move by move. His right hand is on the grip at the
## origin, the rod running ahead along -Z; his left hand is on the butt behind it (`support_point`), or on the reel's
## knob while he reels (`reeling`), turning it round. The rod bends (the model's shape key "bent", `bend` 0..1) and
## its tip goes where the bend takes it (`tip`). `size` scales it all (a smaller rod for a smaller holder).
## From Gloaming's FishingRod (GameCommon godot/fishing).

## How far the rod runs ahead of his hand, and how far the tip is pulled down and back at full bend, at size 1
## (tools/build_fishing.py's ROD_LONG and ROD_BEND).
const LONG := 3.0
const BEND := 1.0
## Where the crank's axle is, and its knob from the axle (the rod's own frame), and the butt, at size 1.
const AXLE := Vector3(-0.035, -0.085, -0.06)
const KNOB := Vector3(-0.028, -0.07, 0.0)
const BUTT := Vector3(0.0, 0.0, 0.3)

var two_handed := true
var kick := 0.0
## The hand's place (from the shoulder) and the way the rod points, in the figure's frame.
var grip := Vector3(0.05, -0.3, 0.25)
var point := Vector3(0.0, 0.5, 1.0)
var bend := 0.0
var reeling := false
## How far the crank has gone round (radians).
var crank := 0.0
## How big it is drawn (1: a man's rod).
var size := 1.0
var _parts: Array[MeshInstance3D] = []
var _crank: Node3D


## Built from the pieces (fishing.glb), `size` times as big.
func build(pieces: Node, rod_size := 1.0) -> void:
	size = rod_size
	var model := FishingSpot.piece(pieces, "rod")
	model.scale = Vector3.ONE * size
	add_child(model)
	_crank = FishingSpot.piece(pieces, "rod_crank")
	_crank.position = AXLE * size
	_crank.scale = Vector3.ONE * size
	add_child(_crank)
	for part: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		if part.find_blend_shape_by_name(&"bent") >= 0:
			_parts.append(part)


func _ready() -> void:
	add_to_group(&"guns")
	freeze = true
	collision_layer = 0
	collision_mask = 0


## Asked by the rig: [where his hand is, the way the rod points], in its frame, from his `shoulder`.
func held_at(shoulder: Vector3) -> Array:
	return [shoulder + grip, point]


## Where his left hand goes (the world): the reel's knob going round, or the butt.
func support_point() -> Vector3:
	if reeling:
		return global_transform * ((AXLE + KNOB.rotated(Vector3.RIGHT, crank)) * size)
	return global_transform * (BUTT * size)


func _process(_delta: float) -> void:
	if _crank:
		_crank.rotation.x = crank
	for part in _parts:
		part.set_blend_shape_value(part.find_blend_shape_by_name(&"bent"), clampf(bend, 0.0, 1.2))


## The rod's tip (the world), bent as it is.
func tip() -> Vector3:
	var b := clampf(bend, 0.0, 1.2)
	return global_transform * (Vector3(0.0, -BEND * b, -(LONG - BEND * 0.38 * b)) * size)
