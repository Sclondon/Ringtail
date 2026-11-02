class_name Critter
extends CharacterBody3D
## A body for a CritterRig (fox, skunk, badger, rabbit, and the grove's animals: GroveAnimals): it
## goes the way `drive` says (metres a second, level), turns to face it, and falls; it gives the rig what it reads
## from a Player. Used by tests/critter_shots.gd.

signal jumped
signal landed(impact_speed: float)
signal respawned

## Its size beside the raccoon (the skeleton is his).
const SIZES := {"fox": 0.95, "skunk": 0.78, "badger": 0.88, "rabbit": 0.72, "beaver": 1.0, "rat": 0.5, "mouse": 0.28,
		"weasel": 0.6, "marten": 0.75, "otter": 1.0, "gopher": 0.5, "prairie_dog": 0.58, "opossum": 0.85, "squirrel": 0.5,
		"porcupine": 0.9, "chipmunk": 0.38}

var walk_speed := 1.0
var run_speed := 4.0
var is_pushing := false
var is_ducking := false
var is_crawling := false
var drive := Vector3.ZERO
var rig: CritterRig
var kind := ""
## How long it has been off the ground (the rig reads it; GroveAnimals holds it at 0 while it carries one up a tree or
## through the water, so it climbs and paddles instead of falling).
var air_time := 0.0


static func make(what: String, low := false) -> Critter:
	var body := Critter.new()
	body.kind = what
	body.rig = CritterRig.make(what, low)
	body.rig.name = "Rig"
	body.rig.scale = Vector3.ONE * SIZES.get(what, 0.85)
	body.rig.dusty = false
	return body


func _ready() -> void:
	collision_layer = 4
	collision_mask = 1
	var shape := CapsuleShape3D.new()
	# (as big as it is drawn)
	var size: float = SIZES.get(kind, 0.85)
	shape.radius = 0.18 * size
	shape.height = maxf(0.6 * size, shape.radius * 2.0)
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.rotation.x = PI / 2
	collider.position.y = 0.24 * size
	add_child(collider)
	add_child(rig)


func _physics_process(delta: float) -> void:
	var fall := velocity.y - 20.0 * delta if not is_on_floor() else -0.1
	velocity = Vector3(drive.x, fall, drive.z)
	if Vector2(drive.x, drive.z).length() > 0.1:
		rotation.y = lerp_angle(rotation.y, atan2(drive.x, drive.z), 1.0 - exp(-8.0 * delta))
	move_and_slide()
	air_time = 0.0 if is_on_floor() else air_time + delta
