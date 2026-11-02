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
const CARS_PER_LOOP := 4  # (all out by day; at night fewer: DayNight parks the rest)
const PEOPLE_PER_WALK := 2
const CROWS_PER_BAND := 4
## How far left of a road's centre line its vehicles keep (they drive on the left, as in Japan).
const LANE := 1.9
## The kinds of vehicle on the roads, in turn (HazardCar.KINDS; the user, 2026-11-02, "there should be different types,
## busses etc"), and the colours a kind always comes in (body, second colour). Claude's picks.
const KIND_MIX := [&"hatchback", &"kei_truck", &"bus", &"taxi", &"kei_van", &"hatchback"]
const KIND_PAINTS := {
	&"bus": [Color(0.25, 0.55, 0.42), Color(0.93, 0.9, 0.8)],
	&"taxi": [Color(0.16, 0.3, 0.22), Color(0.95, 0.85, 0.35)],
	&"kei_truck": [Color(0.93, 0.93, 0.9), Color(0.75, 0.76, 0.78)],
}
## How far round the grove's heart he is safe: nothing chases, stalks or dives at him there (the hill and its slopes).
const HAVEN_RADIUS := 55.0

static var haven := Vector3(0.0, -1000.0, 0.0)
## Paint the cars come in.
const PAINTS := [Color(0.85, 0.22, 0.18), Color(0.2, 0.45, 0.8), Color(0.95, 0.78, 0.2), Color(0.3, 0.65, 0.35),
	Color(0.92, 0.92, 0.9), Color(0.55, 0.3, 0.6)]


static func place(world: Node3D, markers: Dictionary, player: Player) -> void:
	# (no grove: nowhere is safe; `safe` measures across the ground only, so far off across it, not below)
	# (the hill's middle where World has a `haven` marker, else the band's base)
	haven = (markers.get("haven", markers.get("grove_heart", Transform3D.IDENTITY.translated(Vector3(1.0e6, 0.0, 1.0e6)))) as Transform3D).origin
	var road := 0
	for loop: PackedVector3Array in _lines(markers, "road"):
		var lane := _lane(loop)
		for k in CARS_PER_LOOP:
			var car := HazardCar.new()
			car.route = lane
			car.road = road
			car.start = float(k) / CARS_PER_LOOP
			# (a mix of kinds on each road, a bus on every other one)
			car.kind = KIND_MIX[(road * 2 + k) % KIND_MIX.size()]
			if car.kind == &"bus" and road % 2 == 1:
				car.kind = &"hatchback"
			car.paint = PAINTS[(world.get_child_count() + k * 3) % PAINTS.size()]
			if KIND_PAINTS.has(car.kind):
				car.paint = KIND_PAINTS[car.kind][0]
				car.paint2 = KIND_PAINTS[car.kind][1]
			car.stops = _stops(markers, lane)
			car.player = player
			world.add_child(car)
		road += 1
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
			# (most bands leave him be; every third dives at him: Claude's pick)
			band.hostile = name.get_slice("_", 1).to_int() % 3 == 0
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
	# (put away while a bird is played: BirdPlayer)
	if target != null and not target.is_visible_in_tree():
		return true
	return target == null or safe(target.global_position) or hidden(target) or PointStand.perched(target)


## Whether `target` is hidden down in tall grass (TownGrass.hidden; the user, 2026-11-02, "tall grass to hide in in
## spots as well"): on the ground in a patch, and not bounding through it flat out (then the grass thrashes and he
## is seen). Claude's pick of when.
static func hidden(target: Node3D) -> bool:
	# (or down in a bramble thicket: GrovePlants)
	if not (TownGrass.hidden(target.global_position) or GrovePlants.in_thicket(target.global_position)):
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


## Where along `lane` its bus stops are (m): any `bus_stop_<n>` marker within 8 m of it.
static func _stops(markers: Dictionary, lane: PackedVector3Array) -> Array[float]:
	var stops: Array[float] = []
	for name: String in markers:
		if not name.begins_with("bus_stop_"):
			continue
		var at: Vector3 = (markers[name] as Transform3D).origin
		var run := 0.0
		var best := INF
		var best_run := 0.0
		for i in lane.size():
			var d := lane[i].distance_to(at)
			if d < best:
				best = d
				best_run = run
			run += lane[i].distance_to(lane[(i + 1) % lane.size()])
		if best < 8.0:
			stops.append(best_run)
	return stops


## A closed loop's points moved LANE to the left of the way it runs.
static func _lane(loop: PackedVector3Array) -> PackedVector3Array:
	var lane := PackedVector3Array()
	var n := loop.size()
	for i in n:
		var ahead := (loop[(i + 1) % n] - loop[(i - 1 + n) % n])
		ahead.y = 0.0
		ahead = ahead.normalized()
		# (left of the way it runs: +Z ahead has left at +X)
		var left := Vector3(ahead.z, 0.0, -ahead.x)
		lane.append(loop[i] + left * LANE)
	return lane
