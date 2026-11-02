class_name HazardDog
extends CharacterBody3D
## A yard dog (the user, 2026-11-02: "there should be dogs as well (we already have the assets)"): GameCommon's dog
## (godot/dog, Warren's) fed and kept, coat tinted, no mange, living in a yard at a `dog_<n>` marker. It potters
## about its yard (sniffing, sitting, lying down for a sleep); seeing the raccoon near it barks, then gives chase at
## a gallop and springs at him (a bite hurts). He can outrun it bounding flat out; it gives up after a while, when
## he gets too far from its yard, when he goes up out of its reach, or when it loses him: in the grove, or hidden in
## tall grass (Hazards.unseen). Then it casts about with its nose down where it last saw him, and trots home. His
## tail spin sends it yelping home. How near, how fast and the dogs' looks are Claude's picks (placeholders).
##
##   HazardDog.place(world, markers, player)

enum State { POTTER, SIT, SLEEP, ALERT, CHASE, LUNGE, SEARCH, HOME, YELP }

## Each dog's look: [coat tint (over the dog's own dark grey-brown, so strong), size, variant]. Claude's picks; each is
## bigger than the raccoon.
const LOOKS := [
	[Color(5.0, 3.5, 2.0), 1.25, 0],   # a tan shepherd-ish dog
	[Color(0.55, 0.52, 0.52), 1.35, 1], # a big black one
	[Color(5.6, 5.4, 5.0), 1.1, 0],     # a white one
	[Color(3.0, 1.9, 1.1), 1.2, 1],     # a brown one
	[Color(4.6, 4.0, 3.0), 1.0, 1],     # a little cream one
	[Color(2.6, 2.5, 2.4), 1.3, 0],     # a grey one
]

## How far it sees him, how far from its yard it will chase, how long, and how fast it goes.
var notice := 7.5
var leash := 16.0
var chase_time := 7.0
var chase_speed := 5.2
var trot_speed := 2.4
var walk_speed := 0.9

var home := Vector3.ZERO
var player: Player
var dog: Dog
var state := State.POTTER
var _t := 0.0
var _goal := Vector3.ZERO
var _rest := 0.0
var _seen_at := Vector3.ZERO
var _gravity := 20.0


static func place(world: Node3D, markers: Dictionary, hero: Player) -> void:
	var homes: Array[Vector3] = []
	for name: String in markers:
		if name.begins_with("dog_"):
			homes.append((markers[name] as Transform3D).origin)
	if homes.is_empty():
		# (no yards marked yet: a few of the haunts furthest from the grove)
		var spots: Array[Vector3] = []
		for name: String in markers:
			if name.begins_with("haunt_"):
				var at := (markers[name] as Transform3D).origin
				if not Hazards.safe(at):
					spots.append(at)
		spots.sort_custom(func(a: Vector3, b: Vector3) -> bool:
			return Vector2(a.x - Hazards.haven.x, a.z - Hazards.haven.z).length() > Vector2(b.x - Hazards.haven.x, b.z - Hazards.haven.z).length())
		homes = spots.slice(0, 3)
	for k in homes.size():
		world.add_child(make(homes[k], k, hero))


static func make(at: Vector3, k: int, hero: Player) -> HazardDog:
	var body := HazardDog.new()
	body.name = "Dog%d" % k
	body.home = at
	body.player = hero
	body.position = at + Vector3.UP * 0.3
	var look: Array = LOOKS[k % LOOKS.size()]
	body.dog = Dog.new()
	body.dog.name = "Dog"
	body.dog.coat_tint = look[0]
	body.dog.mange = 0.0
	body.dog.eyeshine = 0.2
	body.dog.variant = look[2]
	body.dog.fur_shells = 1
	body.dog.scale = Vector3.ONE * float(look[1])
	return body


func _ready() -> void:
	# (as the hazards are: on its own layer, seeing only the world; the band and the villagers run from it)
	collision_layer = 4
	collision_mask = 1
	add_to_group(&"hazards")
	add_to_group(&"tail_hittable")
	var shape := CapsuleShape3D.new()
	shape.radius = 0.2
	shape.height = 0.9
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.rotation.x = PI / 2
	collider.position.y = 0.35
	add_child(collider)
	add_child(dog)
	kept(dog)
	_goal = home


## A kept dog, not Warren's feral one: no scars or bald patches, the creases of its ribs soft, its coat smoother.
static func kept(which: Dog) -> void:
	if which.rig and which.rig.materials.has("coat"):
		DogLook.tune(which.rig.materials["coat"], {&"scar_width": 0.0, &"scar_bald": 0.0, &"crease": 0.2, &"patch": 0.0,
				&"clump_tone": 0.2, &"streak": 0.05})


func _go(to: State) -> void:
	state = to
	_t = 0.0
	dog.sitting = to == State.SIT
	dog.lying = to == State.SLEEP
	dog.tracking = to == State.SEARCH
	dog.snarling = to == State.CHASE or to == State.LUNGE
	dog.stalking = false


func _physics_process(delta: float) -> void:
	_t += delta
	_rest = maxf(_rest - delta, 0.0)
	var him := player.global_position if player else Vector3.INF
	var to_him := him - global_position
	var level := Vector3(to_him.x, 0.0, to_him.z)
	var near := level.length() if player else INF
	var sees := player != null and near < notice and absf(to_him.y) < 1.3 and not Hazards.unseen(player) \
			and _rest <= 0.0 and him.distance_to(home) < leash
	var drive := Vector3.ZERO
	dog.look_at_point = Vector3.INF
	match state:
		State.POTTER, State.SIT, State.SLEEP:
			if sees and (state != State.SLEEP or near < notice * 0.6):
				dog.bark()
				_go(State.ALERT)
			elif state == State.POTTER:
				if global_position.distance_to(_goal) < 0.4 or _t > 6.0:
					var roll := randf()
					if roll < 0.2:
						_go(State.SIT)
					elif roll < 0.32:
						_go(State.SLEEP)
					else:
						_goal = home + Vector3(randf_range(-2.5, 2.5), 0.0, randf_range(-2.5, 2.5))
						_t = 0.0
						dog.tracking = randf() < 0.5
				drive = _towards(_goal, walk_speed)
			elif _t > (5.0 if state == State.SIT else 14.0):
				_go(State.POTTER)
		State.ALERT:
			# (stock still, staring at him, barking; then away after him)
			dog.look_at_point = him + Vector3.UP * 0.3
			_face(level)
			if _t > 0.25 and _t < 0.3:
				dog.bark()
			if not sees:
				_go(State.POTTER)
			elif _t > 0.7:
				_go(State.CHASE)
		State.CHASE:
			dog.look_at_point = him + Vector3.UP * 0.3
			_seen_at = him
			drive = level.normalized() * chase_speed
			if Hazards.unseen(player) or near > notice * 2.2 or _t > chase_time or him.distance_to(home) > leash \
					or absf(to_him.y) > 1.6:
				_go(State.SEARCH)
			elif near < 2.2 * dog.scale.x:
				dog.lunge(him + Vector3.UP * 0.25)
				_go(State.LUNGE)
		State.LUNGE:
			drive = dog.lunge_push()
			if player and _rest <= 0.0 and dog.bite_hits(him + Vector3.UP * 0.3):
				Hazards.hurt(self, global_position)
				_rest = 2.5
			if dog.lunge_stage() == Dog.Lunge.NONE and _t > 0.2:
				_go(State.CHASE if _rest <= 0.0 and not Hazards.unseen(player) else State.SEARCH)
		State.SEARCH:
			# (nose down, casting about where it last saw him; finds him again if he shows himself)
			drive = _towards(_seen_at + Vector3(sin(_t * 1.7), 0.0, cos(_t * 1.3)) * 1.2, walk_speed * 1.4)
			if sees and _t > 0.6:
				dog.bark()
				_go(State.CHASE)
			elif _t > 3.5:
				_rest = 3.0
				_go(State.HOME)
		State.HOME:
			drive = _towards(home, trot_speed)
			if global_position.distance_to(home) < 0.8:
				_go(State.POTTER)
			elif sees and _t > 1.0:
				dog.bark()
				_go(State.ALERT)
		State.YELP:
			drive = velocity.move_toward(Vector3.ZERO, 6.0 * delta)
			drive.y = 0.0
			if _t > 1.0:
				_rest = 8.0
				_go(State.HOME)
	# Moved as it means to go, falling, and turned to its way
	var vy := velocity.y - _gravity * delta if not is_on_floor() else -0.1
	velocity = Vector3(drive.x, vy, drive.z)
	if state != State.ALERT and Vector2(drive.x, drive.z).length() > 0.1:
		_face(drive)
	move_and_slide()


func _towards(point: Vector3, pace: float) -> Vector3:
	var to := point - global_position
	to.y = 0.0
	return to.normalized() * pace if to.length() > 0.25 else Vector3.ZERO


func _face(way: Vector3, rate := 8.0) -> void:
	if Vector2(way.x, way.z).length() > 0.01:
		rotation.y = lerp_angle(rotation.y, atan2(way.x, way.z), 1.0 - exp(-rate * get_physics_process_delta_time()))


## Hit by his tail: sent yelping off, and home for a good while.
func tail_hit(_from: Vector3, push: Vector3) -> void:
	if state == State.YELP:
		return
	velocity = Vector3(push.x, 3.5, push.z) * 0.8
	dog.shake()
	_go(State.YELP)
