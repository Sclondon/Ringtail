class_name Critter
extends CharacterBody3D
## A stand-in body for a CritterRig (fox, skunk, badger, rabbit) while their part in the game is undecided: it
## goes the way `drive` says (metres a second, level), turns to face it, and falls; it gives the rig what it reads
## from a Player. Used by tests/critter_shots.gd.

signal jumped
signal landed(impact_speed: float)
signal respawned

## Its size beside the raccoon (the skeleton is his).
const SIZES := {"fox": 0.95, "skunk": 0.78, "badger": 0.88, "rabbit": 0.72}

var walk_speed := 1.0
var run_speed := 4.0
var is_pushing := false
var is_ducking := false
var is_crawling := false
var drive := Vector3.ZERO
var rig: CritterRig


static func make(what: String) -> Critter:
	var body := Critter.new()
	body.rig = CritterRig.make(what)
	body.rig.name = "Rig"
	body.rig.scale = Vector3.ONE * SIZES.get(what, 0.85)
	body.rig.dusty = false
	return body


func _ready() -> void:
	collision_layer = 4
	collision_mask = 1
	var shape := CapsuleShape3D.new()
	shape.radius = 0.18
	shape.height = 0.6
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.rotation.x = PI / 2
	collider.position.y = 0.24
	add_child(collider)
	add_child(rig)


func _physics_process(delta: float) -> void:
	var fall := velocity.y - 20.0 * delta if not is_on_floor() else -0.1
	velocity = Vector3(drive.x, fall, drive.z)
	if Vector2(drive.x, drive.z).length() > 0.1:
		rotation.y = lerp_angle(rotation.y, atan2(drive.x, drive.z), 1.0 - exp(-8.0 * delta))
	move_and_slide()
