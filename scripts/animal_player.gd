class_name AnimalPlayer
extends BirdPlayer
## Playing as any of the town's animals (the user, 2026-11-02: "do most of the animals share a rig? there should be
## an option to play as all the animals", then "or at least just to run around the grove as them"): picked on the
## pause screen (PauseMenu's Play as grid), in place of the raccoon, as BirdPlayer plays the crow and the owl (this is
## a BirdPlayer, so everything that asks `BirdPlayer.active` follows it: the zones, the HUD's buttons, the Crumbs, and
## nothing hurts the put-away raccoon).
##
## The mammals (CritterRig.KINDS: fox ... turtle) and the cats are drawn on the raccoon's skeleton by a CritterRig,
## which reads this body as it reads a Critter's; the dogs are YardDogs carried along (GameCommon's Dog strides to how
## it is moved); the snake is a GroveSnake. Each walks and runs as far as the stick is pushed, jumps (frogs and
## rabbits hop as they go), and paddles at the top of deep water. The tail button does a little thing of the kind's
## own: the skunk's spray, the porcupine's quills, the opossum playing dead, the frog's croak, a dog's bark (Claude's
## picks, all light). Crumbs count as his; cages are his alone to break.

## Every animal to play, in the picker's order (the raccoon, crow and owl are BirdPlayer's own).
const ANIMALS := ["fox", "skunk", "badger", "rabbit", "cat_0", "cat_1", "cat_2", "shiba", "beagle", "bloodhound",
		"basset", "dachshund", "beaver", "otter", "rat", "mouse", "weasel", "marten", "gopher", "prairie_dog", "opossum",
		"squirrel", "chipmunk", "porcupine", "ringtail", "frog", "turtle", "snake"]
const DOGS := ["shiba", "beagle", "bloodhound", "basset", "dachshund"]
## Each one's feel: walking and running speed (m/s) and how high it jumps (m). Claude's picks; the rest from its size.
const FEEL := {
	"fox": [1.2, 6.0, 1.0], "rabbit": [1.0, 6.5, 1.3], "skunk": [0.8, 2.4, 0.5], "badger": [0.9, 3.2, 0.6],
	"porcupine": [0.6, 1.8, 0.4], "opossum": [0.8, 2.6, 0.6], "turtle": [0.35, 0.7, 0.15], "frog": [0.6, 1.8, 1.7],
	"mouse": [0.6, 3.2, 0.6], "chipmunk": [0.7, 3.6, 0.8], "squirrel": [0.9, 4.6, 1.1], "ringtail": [0.9, 4.8, 1.2],
	"marten": [1.0, 5.0, 1.1], "weasel": [0.9, 4.6, 0.8], "otter": [0.9, 3.4, 0.7], "beaver": [0.7, 2.4, 0.5],
	"cat": [1.0, 6.0, 1.6], "snake": [0.6, 1.6, 0.3],
}
## Those that hop along rather than walk.
const HOPPERS := ["rabbit", "frog"]
const GRAVITY := 20.0

## For the rig, as a Critter gives it.
signal jumped
signal landed(impact_speed: float)
signal respawned

var walk_speed := 1.0
var run_speed := 4.0
var is_pushing := false
var is_ducking := false
var is_crawling := false
var air_time := 0.0

## What draws it: a CritterRig (mammals, cats), a YardDog or a GroveSnake.
var figure: Node3D
var size := 1.0
var _jump := 0.9
var _hops := false
var _hop_wait := 0.0
var _special := 0.0
var _limp := false
var _fall_from := 0.0
var _puff: CPUParticles3D


## The part of `kind` that names the model (a cat's look number off).
static func species(what: String) -> String:
	return "cat" if what.begins_with("cat") else what


## How big it is drawn beside the raccoon.
static func size_of(what: String) -> float:
	if what in DOGS:
		for breed: Array in HazardDog.BREEDS:
			if breed[0] == what:
				return float(breed[1])
		return 1.3
	if what.begins_with("cat"):
		return 0.85
	if what == "snake":
		return 1.4
	return float(Critter.SIZES.get(what, 0.85))


## What draws `what`, sized, facing +Z, its feet at this node (for a body to carry, or a picture: tools/make_animal_faces.gd).
static func make_figure(what: String) -> Node3D:
	if what in DOGS:
		var dog := YardDog.new()
		dog.breed = what
		dog.friendly = true
		dog.scale = Vector3.ONE * size_of(what)
		return dog
	if what == "snake":
		var snake := GroveSnake.new()
		snake.scale = Vector3.ONE * size_of(what)
		return snake
	var rig: CritterRig
	if what.begins_with("cat"):
		# (a CritterRig is a CatRig: on the cat's model and with its tail by itself; its look one of the town's cats')
		rig = CritterRig.new()
		rig.kind = "cat"
		var look := FurLook.cat(int(what.substr(4)) if what.length() > 4 else 0)
		rig.model = load(FurLook.model_path("cat", look.get("fur", "spiky")))
		rig.look = look
	else:
		rig = CritterRig.make(what)
	rig.name = "Rig"
	rig.scale = Vector3.ONE * size_of(what)
	rig.dusty = false
	return rig


func _ready() -> void:
	var what := String(kind)
	size = size_of(what)
	var feel: Array = FEEL.get(species(what), [])
	if what in DOGS:
		for breed: Array in HazardDog.BREEDS:
			if breed[0] == what:
				feel = [1.2, float(breed[2]), 0.9]
	if feel.is_empty():
		feel = [0.7 + 0.5 * size, 2.5 + 3.0 * size, 0.4 + 0.6 * size]
	walk_speed = feel[0]
	run_speed = feel[1]
	_jump = feel[2]
	_hops = species(what) in HOPPERS
	_cfg = {"walk": walk_speed, "camera": clampf(1.0 + 2.2 * size, 1.5, 4.5)}
	# (as he is: on the second layer, so the Crumbs see it; the world, cars, roofs and wires stop it)
	collision_layer = 2
	collision_mask = 1
	floor_snap_length = 0.15
	floor_max_angle = deg_to_rad(50.0)
	var shape := CapsuleShape3D.new()
	var long := what in DOGS or what == "snake"
	shape.radius = (0.16 if long else 0.18) * size
	shape.height = maxf((0.75 if long else 0.6) * size, shape.radius * 2.0)
	var collider := CollisionShape3D.new()
	collider.shape = shape
	# (lying along it, as a Critter's; its underside at its feet)
	collider.rotation.x = PI / 2
	collider.position.y = shape.radius
	add_child(collider)
	figure = make_figure(what)
	add_child(figure)
	if figure is YardDog:
		(figure as YardDog).grounded = true
	add_to_group(&"tightrope_walkers")
	camera = BirdCamera.new()
	camera.bird = self
	camera.distance = float(_cfg.camera)
	camera.lift = clampf(0.5 * size, 0.2, 0.6)
	world.add_child.call_deferred(camera)
	camera.ready.connect(func() -> void:
		camera.look_along(Vector3(sin(facing_yaw), 0.0, cos(facing_yaw)))
		camera.make_current())
	tree_exiting.connect(func() -> void:
		if is_instance_valid(camera):
			camera.queue_free())


func _physics_process(delta: float) -> void:
	var stick := _stick()
	var grounded := is_on_floor()
	var depth := _depth()
	var swimming := depth > 0.3 * size
	var flat := Vector3(velocity.x, 0.0, velocity.z)
	_special = maxf(_special - delta, 0.0)
	if _just(&"tail"):
		_tail()
	if _limp:
		# (playing dead: lying there till the stick or a button brings it round)
		if stick.length() > 0.3 or _just(&"jump"):
			_limp = false
			(figure as CritterRig).recover()
		velocity = Vector3(0.0, velocity.y - GRAVITY * delta if not grounded else -0.1, 0.0)
		move_and_slide()
		return
	# Walking at a light push, running as it is pushed further (slower swimming)
	var push := stick.length()
	var speed := lerpf(walk_speed, run_speed, smoothstep(0.45, 1.0, push)) * (0.6 if swimming else 1.0)
	var want := stick.normalized() * speed if push > 0.1 else Vector3.ZERO
	flat = flat.move_toward(want, (16.0 if grounded or swimming else 5.0) * delta * maxf(run_speed / 4.0, 0.6))
	var up := velocity.y
	if swimming:
		# (paddling at the top: held up to the surface, bobbing)
		up = move_toward(up, clampf((depth - 0.22 * size) * 6.0, -2.0, 3.0), 18.0 * delta)
		air_time = 0.0
		if _just(&"jump"):
			up = sqrt(2.0 * GRAVITY * maxf(_jump, 0.5))
			jumped.emit()
	elif grounded and up <= 0.01:
		if air_time > 0.2:
			landed.emit(absf(_fall_from))
		air_time = 0.0
		up = -0.5
		_hop_wait -= delta
		if _just(&"jump"):
			up = sqrt(2.0 * GRAVITY * _jump)
			jumped.emit()
		elif _hops and want.length() > 0.2 and _hop_wait <= 0.0:
			# (a rabbit or a frog going along in little hops, longer as it runs)
			up = sqrt(2.0 * GRAVITY * lerpf(0.1, 0.3, push) * (1.4 if species(String(kind)) == "frog" else 1.0))
			_hop_wait = lerpf(0.4, 0.28, push)
	else:
		air_time += delta
		up -= GRAVITY * delta
		_fall_from = up
	velocity = Vector3(flat.x, up, flat.z)
	move_and_slide()
	if global_position.y < World.KILL_Y:
		# (fallen off the world: back where the raccoon was put away, a little over it)
		global_position = world.player.global_position + Vector3.UP * 1.0
		velocity = Vector3.ZERO
		respawned.emit()
	_face(delta)
	_drive_figure(delta, grounded)


## The figure told what it is doing: a dog that it is on the ground or not; the snake how fast it goes.
func _drive_figure(_delta: float, grounded: bool) -> void:
	var going := Vector2(velocity.x, velocity.z).length()
	if figure is YardDog:
		var dog := figure as YardDog
		dog.grounded = grounded or air_time < 0.1
		dog.sitting = going < 0.1 and _special > 0.0
	elif figure is GroveSnake:
		var snake := figure as GroveSnake
		snake.speed = going
		snake.coil = 1.0 if going < 0.05 and _special > 0.0 else 0.0
		snake.lift = 0.6 if _special > 0.0 else 0.0
	elif figure is CritterRig:
		var rig := figure as CritterRig
		rig.bristle = 1.0 if species(String(kind)) == "porcupine" and _special > 0.0 else 0.0
		rig.puff = sin(_special * 12.0) * 0.5 + 0.5 if species(String(kind)) == "frog" and _special > 0.0 else 0.0


## The tail button: the kind's own little thing.
func _tail() -> void:
	var what := species(String(kind))
	_special = 2.0
	if figure is YardDog:
		(figure as YardDog).bark()
	elif what == "opossum" and is_on_floor():
		_limp = true
		(figure as CritterRig).go_limp(Vector3(0.0, 0.5, 0.0))
	elif what == "skunk":
		_spray()


## The skunk's spray: a greenish cloud out behind it.
func _spray() -> void:
	if _puff == null:
		_puff = CPUParticles3D.new()
		_puff.one_shot = true
		_puff.explosiveness = 0.7
		_puff.amount = 24
		_puff.lifetime = 1.6
		var ball := SphereMesh.new()
		ball.radius = 0.12
		ball.height = 0.24
		ball.radial_segments = 8
		ball.rings = 4
		var paint := StandardMaterial3D.new()
		paint.albedo_color = Color(0.7, 0.8, 0.35, 0.45)
		paint.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		paint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		ball.material = paint
		_puff.mesh = ball
		_puff.direction = Vector3(0.0, 0.5, -1.0)
		_puff.spread = 35.0
		_puff.initial_velocity_min = 1.0
		_puff.initial_velocity_max = 2.4
		_puff.gravity = Vector3(0.0, 0.3, 0.0)
		_puff.damping_min = 1.5
		_puff.damping_max = 2.5
		_puff.scale_amount_min = 0.8
		_puff.scale_amount_max = 2.2
		_puff.position = Vector3(0.0, 0.3 * size, -0.25 * size)
		add_child(_puff)
	_puff.restart()


## How far under the surface of any water its feet are (as the Player asks it).
func _depth() -> float:
	var deepest := -1000.0
	for pool: Pool in get_tree().get_nodes_in_group(&"water"):
		deepest = maxf(deepest, pool.depth_at(global_position))
	return deepest
