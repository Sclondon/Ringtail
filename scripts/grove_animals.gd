class_name GroveAnimals
extends Node
## The grove's other animals, living round the clearing (the user, 2026-11-02: "there should be the other animals in
## the grove too for me to see - skunk and beavers and rats and mice and rabbits and weasels and martens and otters",
## "gophers, prairie dogs", "opossums", "squirrels", "porcupine", "chipmunk"). Friendly, not hazards: each keeps to a
## patch of its own round the clearing's rim, the pond and the food pile, and goes about its life there; when the
## raccoon comes near it looks at him and backs off a little, and some have their own ways:
##   - the prairie dogs sit up as sentries by their burrows, and sit up and stare as he comes;
##   - otters and the beaver swim in the pond and come out onto its bank;
##   - mice, rats and chipmunks nibble about the food pile;
##   - squirrels, chipmunks and the porcupine climb the grove's trees, sit up there a while, and come down;
##   - the porcupine raises its quills when he comes too close; the opossum, startled, plays dead.
## How many of each and where is Claude's pick. Far from him they stand still (their rigs off), to spare the frame.
##
##   GroveAnimals.place(world, markers, player)

enum Doing { STAND, WANDER, SENTRY, NIBBLE, CLIMB_UP, PERCH, CLIMB_DOWN, SWIM, DEAD }

## Who lives where: [kind, how many, where (rim, pond, pile, burrow, tree), how far it strays, its pace].
const LIVES := [
	["skunk", 2, "rim", 4.0, 0.7], ["rabbit", 3, "rim", 5.0, 2.4], ["beaver", 1, "pond", 3.0, 0.8],
	["otter", 2, "pond", 3.0, 1.6], ["rat", 2, "pile", 2.0, 1.4], ["mouse", 3, "pile", 1.6, 1.0],
	["weasel", 1, "rim", 6.0, 2.2], ["marten", 1, "tree", 5.0, 1.8], ["gopher", 2, "burrow", 2.0, 0.7],
	["prairie_dog", 3, "burrow", 2.5, 1.2], ["opossum", 1, "rim", 4.0, 0.7], ["squirrel", 3, "tree", 5.0, 2.6],
	["porcupine", 1, "tree", 3.0, 0.45], ["chipmunk", 3, "pile", 3.0, 2.2],
]
## Kinds that climb trees, and how high (m).
const CLIMBERS := {"squirrel": 4.5, "chipmunk": 3.0, "porcupine": 2.4, "marten": 4.0}
## The clearing round the grove's heart is kept for the raccoons: the animals live beyond this.
const CLEAR := 7.0
## He is noticed within this; within the second, they back off.
const NOTICE := 3.5
const SHY := 1.6
## Past this from him they are left standing still.
const FAR := 38.0

var player: Node3D
var heart := Vector3.ZERO
var beasts: Array[Critter] = []
var _life := {}
var _rng := RandomNumberGenerator.new()
var _pool: Pool
var _trees: Array[Node3D] = []


static func place(world: Node3D, markers: Dictionary, hero: Node3D) -> GroveAnimals:
	var life := GroveAnimals.new()
	life.name = "GroveAnimals"
	life.player = hero
	life._rng.seed = 31
	life.heart = (markers["grove_heart"] as Transform3D).origin if markers.has("grove_heart") else hero.global_position
	world.add_child(life)
	life._settle.call_deferred(world)
	return life


## Once the world's bodies are in the physics (the ground is found by rays): everyone out to their places.
func _settle(world: Node3D) -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	for node in world.get_children():
		if node is Pool and (_pool == null or (node as Pool).global_position.distance_to(heart) < _pool.global_position.distance_to(heart)):
			_pool = node
	if _pool and _pool.global_position.distance_to(heart) > 30.0:
		_pool = null
	for node in get_tree().get_nodes_in_group(&"climbable"):
		var tree := node as Node3D
		if tree is StaticBody3D and tree.global_position.length() > 1.0 and tree.global_position.distance_to(heart) < 32.0:
			_trees.append(tree)
	var pile := world.get_node_or_null(^"FoodPile") as Node3D
	var burrows: Array[Vector3] = []
	for k in 4:
		var spot := _rim_spot(14.0, 19.0)
		if spot != Vector3.INF:
			burrows.append(spot)
			var mound: Node3D = (load("res://models/burrow.glb") as PackedScene).instantiate()
			Toon.apply(mound)
			mound.position = spot
			mound.rotation.y = _rng.randf() * TAU
			world.add_child(mound)
	for life: Array in LIVES:
		for n in int(life[1]):
			var where: String = life[2]
			var home := Vector3.INF
			match where:
				"pond":
					if _pool:
						home = _pool.global_position + Vector3(_rng.randf_range(-1.0, 1.0) * _pool.size.x * 0.4, 0.0, _rng.randf_range(-1.0, 1.0) * _pool.size.z * 0.4)
				"pile":
					if pile:
						home = _ground(pile.global_position + Vector3(_rng.randf_range(-1.5, 1.5), 0.0, _rng.randf_range(-1.5, 1.5)))
				"burrow":
					if not burrows.is_empty():
						home = _ground(burrows[n % burrows.size()] + Vector3(_rng.randf_range(-0.8, 0.8), 0.0, _rng.randf_range(-0.8, 0.8)))
				"tree":
					if not _trees.is_empty():
						var tree := _trees[_rng.randi() % _trees.size()]
						home = _ground(tree.global_position + Vector3(_rng.randf_range(-2.5, 2.5), 0.0, _rng.randf_range(-2.5, 2.5)))
			if home == Vector3.INF:
				home = _rim_spot(10.0, 20.0)
			if home == Vector3.INF:
				continue
			_add(world, life, home)


func _add(world: Node3D, life: Array, home: Vector3) -> void:
	var kind: String = life[0]
	var beast := Critter.make(kind, true)
	beast.name = "%s%d" % [kind.capitalize().replace(" ", ""), beasts.size()]
	beast.position = home + Vector3.UP * 0.3
	beast.rotation.y = _rng.randf() * TAU
	world.add_child(beast)
	beasts.append(beast)
	_life[beast] = {"kind": kind, "home": home, "range": float(life[3]), "pace": float(life[4]), "doing": Doing.STAND,
			"t": _rng.randf_range(0.5, 4.0), "goal": home, "tree": null, "climb": 0.0, "far": false}
	if kind == "otter" or kind == "beaver":
		if _pool and _pool.global_position.distance_to(home) < maxf(_pool.size.x, _pool.size.z):
			_go(beast, Doing.SWIM, _rng.randf_range(6.0, 14.0))


## A spot on the ground round the clearing, between `near` and `far` from the grove's heart, or Vector3.INF.
func _rim_spot(near: float, far: float) -> Vector3:
	for _try in 12:
		var a := _rng.randf() * TAU
		var spot := _ground(heart + Vector3(cos(a), 0.0, sin(a)) * _rng.randf_range(maxf(near, CLEAR), far))
		if spot != Vector3.INF and (_pool == null or spot.distance_to(_pool.global_position) > maxf(_pool.size.x, _pool.size.z) * 0.6):
			return spot
	return Vector3.INF


func _ground(at: Vector3) -> Vector3:
	var space := get_viewport().get_world_3d().direct_space_state
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(at + Vector3.UP * 12.0, at + Vector3.DOWN * 20.0, 1))
	return hit.position if not hit.is_empty() else Vector3.INF


func _go(beast: Critter, doing: Doing, seconds: float) -> void:
	var life: Dictionary = _life[beast]
	var was: Doing = life["doing"]
	life["doing"] = doing
	life["t"] = seconds
	beast.rig.always_on_fours = not (doing == Doing.SENTRY or doing == Doing.NIBBLE and life["kind"] in ["squirrel", "chipmunk", "mouse", "rat", "gopher", "prairie_dog"])
	# (off the ground: climbing or swimming it is carried, not walked)
	var carried := doing in [Doing.CLIMB_UP, Doing.PERCH, Doing.CLIMB_DOWN, Doing.SWIM]
	beast.set_physics_process(not carried and doing != Doing.DEAD)
	if not carried and (was in [Doing.CLIMB_UP, Doing.PERCH, Doing.CLIMB_DOWN, Doing.SWIM]):
		beast.rotation.x = 0.0
		beast.rotation.z = 0.0


func _physics_process(delta: float) -> void:
	if player == null:
		return
	for beast in beasts:
		if not is_instance_valid(beast):
			continue
		var life: Dictionary = _life[beast]
		var from_him := beast.global_position - player.global_position
		from_him.y = 0.0
		# (far from him: still, its rig off)
		var far := from_him.length() > FAR
		if far != life["far"]:
			life["far"] = far
			beast.rig.process_mode = Node.PROCESS_MODE_DISABLED if far else Node.PROCESS_MODE_INHERIT
			beast.set_physics_process(not far and not life["doing"] in [Doing.CLIMB_UP, Doing.PERCH, Doing.CLIMB_DOWN, Doing.SWIM, Doing.DEAD])
		if far:
			continue
		_live(beast, life, from_him, delta)


func _live(beast: Critter, life: Dictionary, from_him: Vector3, delta: float) -> void:
	var kind: String = life["kind"]
	life["t"] = float(life["t"]) - delta
	var near := from_him.length() < NOTICE and absf(beast.global_position.y - player.global_position.y) < 2.5
	var doing: Doing = life["doing"]
	if kind == "porcupine":
		beast.rig.bristle = 1.0 if near and from_him.length() < 2.4 else 0.0
	match doing:
		Doing.CLIMB_UP, Doing.PERCH, Doing.CLIMB_DOWN:
			_climbing(beast, life, delta)
			return
		Doing.SWIM:
			_swimming(beast, life, delta)
			return
		Doing.DEAD:
			beast.drive = Vector3.ZERO
			if life["t"] <= 0.0 and not near:
				beast.rig.recover()
				_go(beast, Doing.STAND, 1.5)
			return
	if near:
		match kind:
			"prairie_dog", "gopher":
				# (up on its hind legs, staring at him)
				if doing != Doing.SENTRY:
					_go(beast, Doing.SENTRY, 2.0)
				beast.drive = Vector3.ZERO
				_face(beast, -from_him, delta)
				return
			"opossum":
				if from_him.length() < 2.0 and _rng.randf() < 0.5:
					# (startled: it plays dead, flopped over, until he has gone)
					beast.drive = Vector3.ZERO
					beast.rig.go_limp(Vector3(0.0, 0.5, 0.0))
					_go(beast, Doing.DEAD, _rng.randf_range(5.0, 8.0))
					return
			"porcupine":
				# (it stands its ground, its back to him, quills up)
				beast.drive = Vector3.ZERO
				_face(beast, from_him, delta)
				return
		if from_him.length() < SHY:
			beast.drive = from_him.normalized() * float(life["pace"]) * 1.4
			return
		beast.drive = Vector3.ZERO
		_face(beast, -from_him, delta)
		return
	match doing:
		Doing.WANDER:
			var to_goal: Vector3 = life["goal"] - beast.global_position
			to_goal.y = 0.0
			if to_goal.length() < 0.25 or life["t"] <= 0.0 or _blocked(beast, to_goal):
				_next(beast, life)
			else:
				beast.drive = to_goal.normalized() * float(life["pace"])
		_:
			beast.drive = Vector3.ZERO
			if life["t"] <= 0.0:
				_next(beast, life)


## What it does next: about its patch, or (by kind) a sentry's watch, a nibble, up a tree, into the pond.
func _next(beast: Critter, life: Dictionary) -> void:
	var kind: String = life["kind"]
	var roll := _rng.randf()
	if kind in CLIMBERS and roll < 0.3 and not _trees.is_empty():
		var tree := _nearest_tree(beast.global_position)
		if tree and tree.global_position.distance_to(beast.global_position) < 9.0:
			_start_climb(beast, life, tree)
			return
	if (kind == "otter" or kind == "beaver") and _pool and roll < 0.5:
		beast.global_position = Vector3(beast.global_position.x, _pool.surface_y() - 0.12, beast.global_position.z)
		life["goal"] = _swim_spot()
		_go(beast, Doing.SWIM, _rng.randf_range(8.0, 16.0))
		return
	if kind == "prairie_dog" and roll < 0.45:
		_go(beast, Doing.SENTRY, _rng.randf_range(3.0, 7.0))
		return
	if kind in ["mouse", "rat", "chipmunk", "squirrel", "gopher"] and roll < 0.4:
		_go(beast, Doing.NIBBLE, _rng.randf_range(2.0, 5.0))
		return
	if roll < 0.7:
		var a := _rng.randf() * TAU
		var goal: Vector3 = life["home"] + Vector3(cos(a), 0.0, sin(a)) * _rng.randf_range(0.5, float(life["range"]))
		# (out of the raccoons' clearing)
		var off := goal - heart
		off.y = 0.0
		if off.length() < CLEAR:
			goal = heart + off.normalized() * (CLEAR + 1.0)
		life["goal"] = goal
		_go(beast, Doing.WANDER, 6.0)
	else:
		_go(beast, Doing.STAND, _rng.randf_range(1.5, 4.0))


func _nearest_tree(at: Vector3) -> Node3D:
	var best: Node3D
	for tree in _trees:
		if best == null or tree.global_position.distance_to(at) < best.global_position.distance_to(at):
			best = tree
	return best


## Up a tree: it goes to the trunk, then is carried up it, head first, belly to the bark.
func _start_climb(beast: Critter, life: Dictionary, tree: Node3D) -> void:
	var to_trunk := tree.global_position - beast.global_position
	to_trunk.y = 0.0
	# (where the bark is, from its side: a ray at its middle)
	var from := beast.global_position + Vector3.UP * 0.5
	var hit := beast.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, tree.global_position + Vector3.UP * 0.5, 1))
	var radius := 0.4
	if not hit.is_empty():
		radius = Vector2((hit.position as Vector3).x - tree.global_position.x, (hit.position as Vector3).z - tree.global_position.z).length()
	life["tree"] = tree
	life["radius"] = radius
	life["angle"] = atan2(-to_trunk.x, -to_trunk.z)
	life["climb"] = 0.0
	life["base"] = beast.global_position.y
	_go(beast, Doing.CLIMB_UP, 20.0)


func _climbing(beast: Critter, life: Dictionary, delta: float) -> void:
	var tree: Node3D = life["tree"]
	if not is_instance_valid(tree):
		_go(beast, Doing.STAND, 1.0)
		return
	var high: float = CLIMBERS[life["kind"]]
	var doing: Doing = life["doing"]
	var speed: float = float(life["pace"]) * 0.45
	match doing:
		Doing.CLIMB_UP:
			life["climb"] = minf(float(life["climb"]) + speed * delta, high)
			if life["climb"] >= high:
				_go(beast, Doing.PERCH, _rng.randf_range(5.0, 11.0))
		Doing.PERCH:
			if life["t"] <= 0.0:
				_go(beast, Doing.CLIMB_DOWN, 20.0)
		Doing.CLIMB_DOWN:
			life["climb"] = maxf(float(life["climb"]) - speed * 1.3 * delta, 0.0)
			if life["climb"] <= 0.0:
				var out := Vector3(sin(float(life["angle"])), 0.0, cos(float(life["angle"])))
				beast.global_position = Vector3(tree.global_position.x, float(life["base"]) + 0.2, tree.global_position.z) + out * (float(life["radius"]) + 0.3)
				_go(beast, Doing.STAND, 1.0)
				return
	var out := Vector3(sin(float(life["angle"])), 0.0, cos(float(life["angle"])))
	var size: float = Critter.SIZES.get(life["kind"], 0.6)
	beast.global_position = Vector3(tree.global_position.x, float(life["base"]) + float(life["climb"]), tree.global_position.z) \
			+ out * (float(life["radius"]) + 0.12 * size)
	# (on the bark: nose up the trunk climbing up, down it coming down, its belly to the tree)
	var down := doing == Doing.CLIMB_DOWN
	beast.rotation = Vector3(PI / 2.0 if down else -PI / 2.0, float(life["angle"]) + PI, 0.0)
	beast.drive = Vector3.ZERO
	# (its legs going as it climbs: the rig walks it by its speed, held on the ground)
	beast.air_time = 0.0
	var heading := Vector3(sin(beast.rotation.y), 0.0, cos(beast.rotation.y))
	beast.velocity = heading * (0.0 if doing == Doing.PERCH else speed)


## Swimming about the pond, its back just out of the water; now and then out onto the bank.
func _swimming(beast: Critter, life: Dictionary, delta: float) -> void:
	if _pool == null:
		_go(beast, Doing.STAND, 1.0)
		return
	var goal: Vector3 = life["goal"]
	var to_goal := goal - beast.global_position
	to_goal.y = 0.0
	if to_goal.length() < 0.3:
		life["goal"] = _swim_spot()
	var step := to_goal.normalized() * float(life["pace"]) * delta
	beast.global_position += step
	# (paddling: the rig walks it by its speed, held on the ground)
	beast.air_time = 0.0
	beast.velocity = step / maxf(delta, 0.001)
	beast.global_position.y = _pool.surface_y() - 0.12 + sin(Time.get_ticks_msec() * 0.003 + beast.get_instance_id()) * 0.02
	if step.length() > 0.0001:
		beast.rotation = Vector3(0.0, lerp_angle(beast.rotation.y, atan2(step.x, step.z), 1.0 - exp(-4.0 * delta)), 0.0)
	if life["t"] <= 0.0:
		# (out onto the bank)
		var bank := _ground(_pool.global_position + Vector3(_pool.size.x * 0.65, 0.0, 0.0).rotated(Vector3.UP, _rng.randf() * TAU))
		if bank != Vector3.INF:
			beast.global_position = bank + Vector3.UP * 0.3
			life["home"] = bank
		_go(beast, Doing.STAND, 2.0)


func _swim_spot() -> Vector3:
	return _pool.global_position + Vector3(_rng.randf_range(-0.4, 0.4) * _pool.size.x, 0.0, _rng.randf_range(-0.4, 0.4) * _pool.size.z)


func _face(beast: Critter, way: Vector3, delta: float) -> void:
	if way.length_squared() > 0.0001:
		beast.rotation.y = lerp_angle(beast.rotation.y, atan2(way.x, way.z), 1.0 - exp(-5.0 * delta))


func _blocked(beast: Critter, way: Vector3) -> bool:
	var from := beast.global_position + Vector3.UP * 0.2
	var query := PhysicsRayQueryParameters3D.create(from, from + way.normalized() * 0.5, 1)
	query.exclude = [beast.get_rid()]
	var hit := beast.get_world_3d().direct_space_state.intersect_ray(query)
	return not hit.is_empty() and (hit.normal as Vector3).y < 0.6
