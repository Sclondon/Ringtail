class_name ZoneStreaming
extends Node
## Only the zone he is in is run (the user, 2026-11-02: "make sure to only load stuff in the zone you're in (the grove
## and surround ring is its own zone as well so 5 zones total)"). Everything set out in the world is given to a zone
## (Zones: the four sides and the grove) by where it is, and kept:
##
##   live      in the zone he is in, or home there (where it was set out), or within LIVE_REACH of him: running, shown
##   frozen    a still thing (a tree, a can, a cage, food, a wire) in a zone next to his: shown, not running
##   hidden    anything else: not running, not shown, out of the physics (a node disabled leaves it: disable_mode)
##
## The grove is next to every side, and each side to the grove and the sides either side of it. A paused thing is
## only paused: it goes on from where it was when he comes back (nothing is moved). What follows him (his band, a
## found kit, the one on his back) is never paused. The changes are made a few at a time over the next frames.
## Far meshes are also given a distance past which they are not drawn (FAR_TREES, FAR_SMALL).
##
##   ZoneStreaming.start(world)     # once everything is set out

## Within this of him (m, across the ground) anything is live, whatever its zone (no popping at a zone's edge).
const LIVE_REACH := 30.0
## How many it sets a frame, and how often it looks again at what moves (s).
const PER_FRAME := 120
const LOOK_EVERY := 0.3
## How often a figure far from the camera is posed: every frame within the first, every second frame within the
## next, and so on (CharacterRig.lod_every).
const LOD_STEPS: Array[float] = [12.0, 22.0, 35.0]
## Past these (m) trees and big still things, and small things, are not drawn.
const FAR_TREES := 125.0
const FAR_SMALL := 55.0

enum State { LIVE, FROZEN, HIDDEN }

## Off: everything runs everywhere, as before (for measuring against: tests/perf_zones.gd -- --no-stream, or any
## run with RINGTAIL_NO_STREAM set).
static var enabled := OS.get_environment("RINGTAIL_NO_STREAM") == ""

var world: World
var zones: Zones
## What it keeps: each [node, zone it is home in, still?, state now].
var _things: Array = []
var _next := 0
var _look := 0.0
var _counts := [0, 0, 0]
## Where he was last frame: a jump further than TELEPORT (a respawn, a test putting him down) is set all at once.
var _was := Vector3.INF
const TELEPORT := 8.0


static func start(world: World) -> ZoneStreaming:
	if not enabled:
		return null
	var streaming := ZoneStreaming.new()
	streaming.name = "ZoneStreaming"
	streaming.world = world
	streaming.zones = world.zones
	world.add_child(streaming)
	streaming._gather()
	return streaming


func _gather() -> void:
	if zones == null or zones.names.is_empty():
		return
	var found: Array[Node] = []
	for node in world.get_children():
		if node.get_script() and node.get_script().get_global_name() in [&"Villagers"]:
			found.append_array(node.get_children())
		else:
			found.append(node)
	for node in found:
		var still := _still(node)
		if still < 0:
			continue
		var at := _where(node)
		_things.append([node, zones.zone_of(at), still == 1, State.LIVE, _rig_of(node)])
		_far(node, still == 1)


## 1 a still thing, 0 a moving one, -1 not kept (him, the camera, what follows him, the HUD, the sky, the grass...).
func _still(node: Node) -> int:
	if node == world.player or node == world.camera or not node is Node3D:
		return -1
	var kind: StringName = node.get_script().get_global_name() if node.get_script() else &""
	if kind in [&"Pickup", &"TrashCan", &"Cage", &"Tightrope", &"FoodPile", &"Pool", &"FishingSpot"]:
		return 1
	if kind in [&"Villager", &"Critter", &"HazardCar", &"HazardPerson", &"HazardDog", &"HazardFox", &"HazardBird",
			&"HazardOwl", &"HazardCrows", &"YardCat", &"GroveSnake"]:
		return 0
	# (the trees and other still bodies set out, by where they stand)
	if kind == &"" and node is StaticBody3D:
		return 1
	return -1


## A moving thing's figure (CharacterRig), to pose less often far off; null if it has none.
func _rig_of(node: Node) -> CharacterRig:
	var rig: Variant = node.get(&"rig")
	if rig is CharacterRig:
		return rig
	for child in node.get_children():
		if child is CharacterRig:
			return child
	return null


## Where a thing is, for its zone (a wire: its middle; a band of crows: its home).
func _where(node: Node) -> Vector3:
	if node is Tightrope:
		return ((node as Tightrope).from + (node as Tightrope).to) * 0.5
	if node is HazardCrows:
		return (node as HazardCrows).home
	return (node as Node3D).global_position


## Not drawn past a distance: trees and still bodies far, small things nearer.
func _far(node: Node, still: bool) -> void:
	var reach := FAR_TREES if node is StaticBody3D else FAR_SMALL
	if not still:
		return
	for part in node.find_children("*", "GeometryInstance3D", true, false):
		var geometry := part as GeometryInstance3D
		if geometry.visibility_range_end <= 0.0:
			geometry.visibility_range_end = reach
			geometry.visibility_range_end_margin = 8.0
			geometry.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF


func _who() -> Vector3:
	var bird := BirdPlayer.active(world)
	return bird.global_position if bird else world.player.global_position


func _near(a: int, b: int) -> bool:
	if a == b or a == zones.grove or b == zones.grove:
		return true
	var sides := zones.grove
	return a >= 0 and b >= 0 and (absi(a - b) == 1 or absi(a - b) == sides - 1)


func _process(delta: float) -> void:
	if _things.is_empty():
		return
	var him := _who()
	var jumped := _was == Vector3.INF or him.distance_to(_was) > TELEPORT
	_was = him
	_look -= delta
	if _look > 0.0 and _next == 0 and not jumped:
		return
	if _next == 0 or jumped:
		_look = LOOK_EVERY
		_next = 0
	var here := zones.zone_of(him)
	var camera := get_viewport().get_camera_3d()
	var eye := camera.global_position if camera else him
	# (freed meanwhile: a Crumb taken, a lid knocked off: let go)
	if _next == 0:
		_things = _things.filter(func(thing: Array) -> bool: return is_instance_valid(thing[0]))
	var end := _things.size() if jumped else mini(_next + PER_FRAME, _things.size())
	for k in range(_next, end):
		var thing: Array = _things[k]
		if not is_instance_valid(thing[0]):
			continue
		var node: Node = thing[0]
		_apply(thing, _wanted(thing, node, here, him))
		# (a live figure far from the camera is posed less often)
		var rig: CharacterRig = thing[4]
		if rig and thing[3] == State.LIVE and is_instance_valid(rig):
			var d := eye.distance_to(rig.global_position)
			var every := 1
			for step in LOD_STEPS:
				if d > step:
					every += 1
			rig.lod_every = every
	_next = 0 if end >= _things.size() else end


func _wanted(thing: Array, node: Node, here: int, him: Vector3) -> State:
	# (what follows him is never paused)
	if node is Villager and ((node as Villager).leader != null):
		return State.LIVE
	var at := _where(node)
	if Vector2(at.x - him.x, at.z - him.z).length() < LIVE_REACH:
		return State.LIVE
	var home: int = thing[1]
	var now := home if thing[2] else zones.zone_of(at)
	if home == here or now == here:
		return State.LIVE
	if thing[2] and _near(now, here):
		return State.FROZEN
	return State.HIDDEN


func _apply(thing: Array, state: State) -> void:
	var node: Node3D = thing[0]
	if thing[3] == state:
		# (put back out meanwhile by another, as DayNight brings its cars out by day: away again, kept so)
		if state != State.LIVE and node.process_mode != Node.PROCESS_MODE_DISABLED:
			node.set_meta(&"stream_mode", node.process_mode)
			node.process_mode = Node.PROCESS_MODE_DISABLED
			node.visible = state == State.FROZEN
		return
	if thing[3] == State.LIVE:
		node.set_meta(&"stream_mode", node.process_mode)
	_counts[thing[3]] -= 1
	thing[3] = state
	_counts[state] += 1
	match state:
		State.LIVE:
			# (a car or a walker DayNight has put away for the night stays away)
			if node.has_meta(&"put_away_by_night"):
				return
			node.process_mode = node.get_meta(&"stream_mode", Node.PROCESS_MODE_INHERIT)
			node.visible = true
		State.FROZEN:
			node.process_mode = Node.PROCESS_MODE_DISABLED
			node.visible = true
		State.HIDDEN:
			node.process_mode = Node.PROCESS_MODE_DISABLED
			node.visible = false


## How many are live, frozen and hidden now (for tests).
func counts() -> Array:
	var made := [0, 0, 0]
	for thing: Array in _things:
		if is_instance_valid(thing[0]):
			made[thing[3]] += 1
	return made


## The state a node is kept in (-1: not kept), for tests.
func state_of(node: Node) -> int:
	for thing: Array in _things:
		if is_instance_valid(thing[0]) and thing[0] == node:
			return thing[3]
	return -1
