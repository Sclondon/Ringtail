class_name Hazards
## Everything in town that the raccoon has to keep away from (the user, 2026-11-01: "there should be birds and other
## predators to avoid, and people as well and cars"): crows, a hawk, a fox, townsfolk and cars. One call puts them
## all where the world's markers say:
##
##     Hazards.place(world, world.markers, player)
##
## The markers (Node3D empties in the world model, as World.markers has them: name -> Transform3D):
##     road_<loop>_<i>     the centre line of a closed road loop, its points in order (cars drive it on the right)
##     walk_<route>_<i>    a pavement path, its points in order (people stroll it, there and back)
##     hawk_<n>            the middle of the sky a hawk circles over (at its height on the ground)
##     crows_<n>           where a little band of crows hangs about
##     den_<n>             where a fox lives
## Anything that hurts him calls the game's `hurt(from)` (World.hurt).
##     grove_heart         the middle of the grove: nothing hunts him within HAVEN_RADIUS of it (the user, 2026-11-02:
##                         "you should spawn in the center of the grove and there shouldnt be enemies there")

## How many of each, per marker (Claude's picks).
const CARS_PER_LOOP := 2
const PEOPLE_PER_WALK := 2
const CROWS_PER_BAND := 4
## How far right of a road's centre line its cars keep.
const LANE := 1.6
## How far round the grove's heart he is safe: nothing chases, stalks or dives at him there (the hill and its slopes).
const HAVEN_RADIUS := 21.0

static var haven := Vector3(0.0, -1000.0, 0.0)
## Paint the cars come in.
const PAINTS := [Color(0.85, 0.22, 0.18), Color(0.2, 0.45, 0.8), Color(0.95, 0.78, 0.2), Color(0.3, 0.65, 0.35),
	Color(0.92, 0.92, 0.9), Color(0.55, 0.3, 0.6)]


static func place(world: Node3D, markers: Dictionary, player: Player) -> void:
	haven = (markers["grove_heart"] as Transform3D).origin if markers.has("grove_heart") else Vector3(0.0, -1000.0, 0.0)
	for loop: PackedVector3Array in _lines(markers, "road"):
		var lane := _lane(loop)
		for k in CARS_PER_LOOP:
			var car := HazardCar.new()
			car.route = lane
			car.start = float(k) / CARS_PER_LOOP
			car.paint = PAINTS[(world.get_child_count() + k * 3) % PAINTS.size()]
			car.player = player
			world.add_child(car)
	var seed := 1
	for walk: PackedVector3Array in _lines(markers, "walk"):
		for k in PEOPLE_PER_WALK:
			var person := HazardPerson.new()
			person.route = walk
			person.start = float(k) / PEOPLE_PER_WALK
			person.look_seed = seed * 7 + k
			person.player = player
			world.add_child(person)
		seed += 1
	for name: String in markers:
		var at: Vector3 = markers[name].origin
		if name.begins_with("hawk_"):
			var hawk := HazardBird.new()
			hawk.kind = HazardBird.Kind.HAWK
			hawk.home = at
			hawk.player = player
			world.add_child(hawk)
		elif name.begins_with("crows_"):
			var band := HazardCrows.new()
			band.home = at
			band.count = CROWS_PER_BAND
			band.player = player
			world.add_child(band)
		elif name.begins_with("den_"):
			var fox := HazardFox.spawn()
			fox.home = at
			fox.player = player
			fox.position = at
			world.add_child(fox)


## Whether `at` is in the grove, where nothing hunts him.
static func safe(at: Vector3) -> bool:
	return Vector2(at.x - haven.x, at.z - haven.z).length() < HAVEN_RADIUS


## Whether what hunts can neither see nor get at `target`: in the grove (`safe`), or hidden (`hidden`). Every hunter
## asks this: the dogs, cats, fox, hawk, crows, owl and people.
static func unseen(target: Node3D) -> bool:
	return target == null or safe(target.global_position) or hidden(target)


## Whether `target` is hidden down in tall grass (TownGrass.hidden; the user, 2026-11-02, "tall grass to hide in in
## spots as well"): on the ground in a patch, and not bounding through it flat out (then the grass thrashes and he
## is seen). Claude's pick of when.
static func hidden(target: Node3D) -> bool:
	if not TownGrass.hidden(target.global_position):
		return false
	var body := target as CharacterBody3D
	if body and not body.is_on_floor():
		return false
	return not (&"is_sprinting" in target and target.is_sprinting)


## The game's hurt (World.hurt), from `at`.
static func hurt(node: Node, at: Vector3) -> void:
	var game := node.get_tree().get_first_node_in_group(&"game")
	if game and game.has_method(&"hurt"):
		game.hurt(at)


## Each line of markers called <prefix>_<line>_<i>, its points in order.
static func _lines(markers: Dictionary, prefix: String) -> Array[PackedVector3Array]:
	var found := {}
	for name: String in markers:
		var parts := name.split("_")
		if parts.size() == 3 and parts[0] == prefix and parts[1].is_valid_int() and parts[2].is_valid_int():
			var line := int(parts[1])
			if not found.has(line):
				found[line] = {}
			found[line][int(parts[2])] = (markers[name] as Transform3D).origin
	var lines: Array[PackedVector3Array] = []
	var keys := found.keys()
	keys.sort()
	for line in keys:
		var points := PackedVector3Array()
		var order: Array = found[line].keys()
		order.sort()
		for i in order:
			points.append(found[line][i])
		if points.size() >= 2:
			lines.append(points)
	return lines


## A closed loop's points moved LANE to the right of the way it runs.
static func _lane(loop: PackedVector3Array) -> PackedVector3Array:
	var lane := PackedVector3Array()
	var n := loop.size()
	for i in n:
		var ahead := (loop[(i + 1) % n] - loop[(i - 1 + n) % n])
		ahead.y = 0.0
		ahead = ahead.normalized()
		# (right of the way it runs: +Z ahead has right at -X)
		var right := Vector3(-ahead.z, 0.0, ahead.x)
		lane.append(loop[i] + right * LANE)
	return lane
