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
##   - the porcupine raises its quills when he comes too close; the opossum, startled, plays dead;
##   - ringtails ("and ringtails") bound about and climb the trees;
##   - turtles ("and turtles and frogs") bask on the pond's bank and slip into the water as he comes, swimming slowly;
##     frogs sit at the water's edge and on lily pads, croak (their throats puffed), hop, and leap into the pond;
##   - garter snakes ("and snakes": GroveSnake) sun coiled on warm rocks, flick their tongues, slither about, and
##     slide off into the grass or the pond when he comes near.
## The fishing jetty's end of the pond (`fishing_spot`) is left to him.
## How many of each and where is Claude's pick. Far from him they stand still (their rigs off), to spare the frame.
##
##   GroveAnimals.place(world, markers, player)

enum Doing { STAND, WANDER, SENTRY, NIBBLE, CLIMB_UP, PERCH, CLIMB_DOWN, SWIM, DEAD, CROAK, TO_WATER, PAD }

## Who lives where: [kind, how many, where (rim, pond, bank, pile, burrow, tree), how far it strays, its pace].
const LIVES := [
	["skunk", 2, "rim", 4.0, 0.7], ["rabbit", 3, "rim", 5.0, 2.4], ["beaver", 1, "pond", 3.0, 0.8],
	["otter", 2, "pond", 3.0, 1.6], ["rat", 2, "pile", 2.0, 1.4], ["mouse", 3, "pile", 1.6, 1.0],
	["weasel", 1, "rim", 6.0, 2.2], ["marten", 1, "tree", 5.0, 1.8], ["gopher", 2, "burrow", 2.0, 0.7],
	["prairie_dog", 3, "burrow", 2.5, 1.2], ["opossum", 1, "rim", 4.0, 0.7], ["squirrel", 3, "tree", 5.0, 2.6],
	["porcupine", 1, "tree", 3.0, 0.45], ["chipmunk", 3, "pile", 3.0, 2.2], ["ringtail", 2, "tree", 5.0, 2.4],
	["turtle", 2, "bank", 1.2, 0.3], ["frog", 4, "bank", 1.0, 1.0],
]
## Kinds that climb trees, and how high (m).
const CLIMBERS := {"squirrel": 4.5, "chipmunk": 3.0, "porcupine": 2.4, "marten": 4.0, "ringtail": 4.5}
## Kinds that take to the pond.
const SWIMMERS := ["otter", "beaver", "turtle", "frog"]
## Garter snakes, and the warm rocks they sun on.
const SNAKES := 2
## States in which it is carried (placed by hand, its body's physics off).
const CARRIED := [Doing.CLIMB_UP, Doing.PERCH, Doing.CLIMB_DOWN, Doing.SWIM, Doing.PAD]
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
var snakes: Array[GroveSnake] = []
var _snake_life := {}
var _pads: Array[Vector3] = []
## Where the fishing jetty is (kept clear), or Vector3.INF.
var _jetty := Vector3.INF


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
	var markers: Dictionary = world.get(&"markers") if &"markers" in world else {}
	if markers.has("fishing_spot"):
		_jetty = (markers["fishing_spot"] as Transform3D).origin
	elif _pool:
		# (PondFishing's own pick when there is no marker: the west bank)
		_jetty = _pool.global_position + Vector3(-(_pool.size.x * 0.5 + 0.5), 0.0, 0.0)
	if _pool:
		_lily_pads(world)
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
						home = _swim_spot()
				"bank":
					if _pool:
						home = _bank()
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
	for k in SNAKES:
		var rock := _rim_spot(9.0, 17.0)
		if rock != Vector3.INF:
			_add_snake(world, rock)


## Lily pads on the pond, away from the jetty: flat green rounds a frog sits on.
func _lily_pads(world: Node3D) -> void:
	var green := Toon.surface(Color(0.3, 0.5, 0.18))
	for k in 5:
		var at := _swim_spot()
		if at == Vector3.INF:
			continue
		var pad := MeshInstance3D.new()
		var disc := CylinderMesh.new()
		disc.top_radius = _rng.randf_range(0.16, 0.24)
		disc.bottom_radius = disc.top_radius
		disc.height = 0.012
		disc.radial_segments = 12
		disc.rings = 1
		pad.mesh = disc
		pad.material_override = green
		pad.name = "LilyPad%d" % k
		world.add_child(pad)
		pad.global_position = Vector3(at.x, _pool.surface_y() + 0.008, at.z)
		_pads.append(pad.global_position)


## A sunning rock on the rim and a snake on it.
func _add_snake(world: Node3D, at: Vector3) -> void:
	var rock := StaticBody3D.new()
	rock.name = "SnakeRock%d" % snakes.size()
	var model: Node3D = (load("res://models/snake_rock.glb") as PackedScene).instantiate()
	Toon.apply(model)
	rock.add_child(model)
	for part: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		var shape := CollisionShape3D.new()
		shape.shape = part.mesh.create_convex_shape()
		rock.add_child(shape)
	world.add_child(rock)
	rock.global_position = at
	rock.rotation.y = _rng.randf() * TAU
	var snake := GroveSnake.new()
	snake.name = "Snake%d" % snakes.size()
	world.add_child(snake)
	snake.global_position = at + Vector3.UP * 0.25
	snake.rotation.y = _rng.randf() * TAU
	snake.coil = 1.0
	snakes.append(snake)
	_snake_life[snake] = {"rock": at, "doing": Doing.STAND, "t": _rng.randf_range(6.0, 14.0), "goal": at, "y": at.y + 0.25}


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
	elif kind == "frog" and not _pads.is_empty() and _rng.randf() < 0.6:
		# (sitting on a lily pad)
		var pad := _pads[_rng.randi() % _pads.size()]
		_life[beast]["goal"] = pad
		_go(beast, Doing.PAD, _rng.randf_range(4.0, 9.0))


## A spot on the pond's bank, just out of the water, clear of the jetty; or Vector3.INF.
func _bank() -> Vector3:
	for _try in 10:
		var a := _rng.randf() * TAU
		var edge := _pool.global_position + Vector3(cos(a) * (_pool.size.x * 0.5 + 0.35), 0.0, sin(a) * (_pool.size.z * 0.5 + 0.35))
		if _jetty != Vector3.INF and Vector2(edge.x - _jetty.x, edge.z - _jetty.z).length() < 2.2:
			continue
		var spot := _ground(edge)
		if spot != Vector3.INF:
			return spot
	return Vector3.INF


## A spot on the ground round the clearing, between `near` and `far` from the grove's heart, or Vector3.INF.
func _rim_spot(near: float, far: float) -> Vector3:
	for _try in 12:
		var a := _rng.randf() * TAU
		var at := heart + Vector3(cos(a), 0.0, sin(a)) * _rng.randf_range(maxf(near, CLEAR), far)
		var space := get_viewport().get_world_3d().direct_space_state
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(at + Vector3.UP * 12.0, at + Vector3.DOWN * 20.0, 1))
		# (on the open ground: not a roof, a rock or a limb)
		if hit.is_empty() or (hit.normal as Vector3).y < 0.9 or absf((hit.position as Vector3).y - heart.y) > 2.0:
			continue
		var spot: Vector3 = hit.position
		if (_pool == null or spot.distance_to(_pool.global_position) > maxf(_pool.size.x, _pool.size.z) * 0.6):
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
	var carried := doing in CARRIED
	beast.set_physics_process(not carried and doing != Doing.DEAD)
	if not carried and was in CARRIED:
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
			beast.set_physics_process(not far and not life["doing"] in CARRIED and life["doing"] != Doing.DEAD)
		if far:
			continue
		_live(beast, life, from_him, delta)
	for snake in snakes:
		if is_instance_valid(snake):
			_snake(snake, _snake_life[snake], delta)


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
		Doing.PAD:
			_on_pad(beast, life, near, delta)
			return
		Doing.TO_WATER:
			_to_water(beast, life)
			return
		Doing.CROAK:
			# (its throat blown out and let go, two or three times a second)
			beast.rig.puff = maxf(0.0, sin(float(life["t"]) * 15.0))
			if life["t"] <= 0.0 or near:
				beast.rig.puff = 0.0
				_go(beast, Doing.STAND, 1.0)
			return
		Doing.DEAD:
			beast.drive = Vector3.ZERO
			if life["t"] <= 0.0 and not near:
				beast.rig.recover()
				_go(beast, Doing.STAND, 1.5)
			return
	if near and kind in ["turtle", "frog"] and _pool:
		# (into the pond: the turtle slips in, the frog leaps)
		_start_to_water(beast, life)
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
				if kind == "frog" and beast.is_on_floor():
					# (hops, not steps)
					beast.hop = 2.2
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
	if kind == "frog" and roll < 0.45:
		_go(beast, Doing.CROAK, _rng.randf_range(1.5, 3.5))
		return
	if kind == "turtle" and roll < 0.6:
		# (basking a good while)
		_go(beast, Doing.STAND, _rng.randf_range(8.0, 18.0))
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
	beast.global_position.y = _pool.surface_y() - 0.12 * float(Critter.SIZES.get(life["kind"], 1.0)) + sin(Time.get_ticks_msec() * 0.003 + beast.get_instance_id()) * 0.02
	if step.length() > 0.0001:
		beast.rotation = Vector3(0.0, lerp_angle(beast.rotation.y, atan2(step.x, step.z), 1.0 - exp(-4.0 * delta)), 0.0)
	if life["t"] <= 0.0:
		# (out onto the bank)
		var bank := _bank()
		if bank != Vector3.INF:
			beast.global_position = bank + Vector3.UP * 0.3
			life["home"] = bank
		if life["kind"] == "frog" and not _pads.is_empty() and _rng.randf() < 0.5:
			life["goal"] = _pads[_rng.randi() % _pads.size()]
			_go(beast, Doing.PAD, _rng.randf_range(5.0, 10.0))
			return
		_go(beast, Doing.STAND, _rng.randf_range(8.0, 16.0) if life["kind"] == "turtle" else 2.0)


## A spot on the pond (at its middle's height), away from the jetty.
func _swim_spot() -> Vector3:
	var spot := _pool.global_position
	for _try in 6:
		spot = _pool.global_position + Vector3(_rng.randf_range(-0.4, 0.4) * _pool.size.x, 0.0, _rng.randf_range(-0.4, 0.4) * _pool.size.z)
		if _jetty == Vector3.INF or Vector2(spot.x - _jetty.x, spot.z - _jetty.z).length() > 2.2:
			break
	return spot


## Off to the water: the nearest bit of the pond, a frog leaping, a turtle walking.
func _start_to_water(beast: Critter, life: Dictionary) -> void:
	var middle := _pool.global_position
	var off := beast.global_position - middle
	off.y = 0.0
	# (just inside the edge, on its side of the pond)
	var half := Vector2(_pool.size.x, _pool.size.z) * 0.5
	var out := off.normalized()
	var reach := minf(half.x / maxf(absf(out.x), 0.01), half.y / maxf(absf(out.z), 0.01))
	life["goal"] = middle + out * maxf(reach - 0.6, 0.0)
	if life["kind"] == "frog":
		beast.hop = 3.4
	_go(beast, Doing.TO_WATER, 4.0)


func _to_water(beast: Critter, life: Dictionary) -> void:
	var to_goal: Vector3 = life["goal"] - beast.global_position
	to_goal.y = 0.0
	var pace := 2.4 if life["kind"] == "frog" else 0.7
	beast.drive = to_goal.normalized() * pace
	if life["kind"] == "frog" and beast.is_on_floor():
		beast.hop = 3.0
	# (over the water, and down to it: in)
	if to_goal.length() < 0.3 or _pool.depth_at(beast.global_position + Vector3.UP * 0.05) > -999.0 or life["t"] <= 0.0:
		beast.drive = Vector3.ZERO
		beast.global_position.y = _pool.surface_y() - 0.1
		life["goal"] = _swim_spot()
		_go(beast, Doing.SWIM, _rng.randf_range(5.0, 10.0) if life["kind"] == "frog" else _rng.randf_range(10.0, 18.0))


## Sitting on a lily pad, croaking now and then; plop into the water when he comes near.
func _on_pad(beast: Critter, life: Dictionary, near: bool, delta: float) -> void:
	var pad: Vector3 = life["goal"]
	beast.global_position = pad + Vector3.UP * 0.006
	beast.air_time = 0.0
	beast.velocity = Vector3.ZERO
	beast.drive = Vector3.ZERO
	beast.rig.puff = maxf(0.0, sin(Time.get_ticks_msec() * 0.015)) if fmod(float(life["t"]), 4.0) < 1.2 else 0.0
	if near:
		beast.rig.puff = 0.0
		life["goal"] = _swim_spot()
		beast.global_position.y = _pool.surface_y() - 0.1
		_go(beast, Doing.SWIM, _rng.randf_range(4.0, 8.0))
	elif life["t"] <= 0.0:
		life["t"] = _rng.randf_range(5.0, 10.0)
		beast.rotation.y += _rng.randf_range(-1.0, 1.0)
	_face(beast, Vector3(sin(beast.rotation.y), 0.0, cos(beast.rotation.y)), delta)


## A garter snake: sunning coiled on its rock, then slithering about the rim, back to its rock; when he comes near it
## uncoils and slides away from him (into the pond if that is the nearer, swimming across it).
func _snake(snake: GroveSnake, life: Dictionary, delta: float) -> void:
	var from_him := snake.global_position - player.global_position
	from_him.y = 0.0
	if from_him.length() > FAR:
		snake.speed = 0.0
		return
	life["t"] = float(life["t"]) - delta
	var doing: Doing = life["doing"]
	var near := from_him.length() < NOTICE
	if near and doing != Doing.TO_WATER and doing != Doing.SWIM:
		# (away from him: into the pond if it is near, else off into the grass)
		var goal := snake.global_position + from_him.normalized() * 4.0
		if _pool and _pool.global_position.distance_to(snake.global_position) < 7.0:
			goal = _swim_spot()
		life["goal"] = goal
		life["doing"] = Doing.TO_WATER
		life["t"] = 6.0
		doing = Doing.TO_WATER
	match doing:
		Doing.STAND:
			# (sunning: coiled, its head up a little, still)
			snake.coil = 1.0
			snake.speed = 0.0
			snake.lift = 0.02
			if life["t"] <= 0.0:
				var a := _rng.randf() * TAU
				life["goal"] = (life["rock"] as Vector3) + Vector3(cos(a), 0.0, sin(a)) * _rng.randf_range(1.5, 4.0)
				life["doing"] = Doing.WANDER
				life["t"] = 14.0
		Doing.WANDER, Doing.TO_WATER:
			snake.coil = 0.0
			snake.lift = 0.03
			var fleeing := doing == Doing.TO_WATER
			_slither(snake, life["goal"], 0.55 if fleeing else 0.22, delta)
			var to_goal: Vector3 = life["goal"] - snake.global_position
			to_goal.y = 0.0
			if fleeing and _pool and _pool.depth_at(snake.global_position + Vector3.UP * 0.05) > -999.0:
				life["doing"] = Doing.SWIM
				life["goal"] = _swim_spot()
				life["t"] = _rng.randf_range(6.0, 10.0)
			elif to_goal.length() < 0.3 or life["t"] <= 0.0:
				if fleeing or _rng.randf() < 0.5:
					# (back to its rock to sun)
					life["goal"] = life["rock"]
					life["doing"] = Doing.PERCH
					life["t"] = 20.0
				else:
					life["doing"] = Doing.STAND
					life["t"] = 0.0
		Doing.PERCH:
			# (going home to its rock)
			snake.coil = 0.0
			_slither(snake, life["goal"], 0.22, delta)
			var home: Vector3 = life["goal"] - snake.global_position
			home.y = 0.0
			if home.length() < 0.25 or life["t"] <= 0.0:
				life["doing"] = Doing.STAND
				life["t"] = _rng.randf_range(10.0, 20.0)
		Doing.SWIM:
			# (across the pond, its head up, then out on the bank)
			snake.coil = 0.0
			snake.lift = 0.04
			_slither(snake, life["goal"], 0.35, delta, _pool.surface_y() - 0.015)
			var across: Vector3 = life["goal"] - snake.global_position
			across.y = 0.0
			if across.length() < 0.3:
				life["goal"] = _swim_spot()
			if life["t"] <= 0.0:
				var bank := _bank()
				if bank != Vector3.INF:
					life["goal"] = bank
				life["doing"] = Doing.PERCH
				life["t"] = 25.0


## Slithers it towards `goal` at `pace`, turning gently and following the ground (or at `water` height).
func _slither(snake: GroveSnake, goal: Vector3, pace: float, delta: float, water := INF) -> void:
	var way := goal - snake.global_position
	way.y = 0.0
	if way.length() < 0.05:
		snake.speed = 0.0
		return
	snake.rotation.y = lerp_angle(snake.rotation.y, atan2(way.x, way.z), 1.0 - exp(-2.5 * delta))
	var ahead := Vector3(sin(snake.rotation.y), 0.0, cos(snake.rotation.y))
	snake.speed = pace
	var at := snake.global_position + ahead * pace * delta
	if water != INF and _pool and _pool.depth_at(Vector3(at.x, _pool.surface_y() - 0.05, at.z)) > -999.0:
		at.y = water
	else:
		# (a short ray: not up onto a tree's limbs)
		var hit := get_viewport().get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(at + Vector3.UP * 0.45, at + Vector3.DOWN * 1.5, 1))
		var ground: Vector3 = hit.position if not hit.is_empty() else Vector3.INF
		at.y = ground.y if ground != Vector3.INF else at.y
	snake.global_position = at


func _face(beast: Critter, way: Vector3, delta: float) -> void:
	if way.length_squared() > 0.0001:
		beast.rotation.y = lerp_angle(beast.rotation.y, atan2(way.x, way.z), 1.0 - exp(-5.0 * delta))


func _blocked(beast: Critter, way: Vector3) -> bool:
	var from := beast.global_position + Vector3.UP * 0.2
	var query := PhysicsRayQueryParameters3D.create(from, from + way.normalized() * 0.5, 1)
	query.exclude = [beast.get_rid()]
	var hit := beast.get_world_3d().direct_space_state.intersect_ray(query)
	return not hit.is_empty() and (hit.normal as Vector3).y < 0.6
