class_name Zones
extends Node
## The hill's four sides, each a zone with food and kits of its own to find (the user, 2026-11-02: "it should be a 4
## sided hill ... breaking the map up into 4 zones. Each zone should be themed a little different and have different
## kit and food trackers"). A side is a `zone_<n>_<Name>` marker at its middle; anything belongs to the side whose
## marker is nearest (across the ground). The grove and the woods and the ring road round it are a zone of their own,
## the fifth (the user, 2026-11-02: "the grove and surround ring is its own zone as well so 5 zones total"): within
## `GROVE_RADIUS` of the grove's heart. The HUD shows the counts of the zone he is in (in the grove: the grove's food,
## and how many of all the lost raccoons are home). ZoneStreaming runs only the zone he is in.
##
##   world.zones = Zones.place(world)     # once the Crumbs, cans and lost kits are out

signal changed

## How far the grove's zone reaches from its heart (m): the clearing, the woods round it and the ring road
## (build_town.py: ROAD's outer edge 47.6).
const GROVE_RADIUS := 48.0

var world: World
## Each zone: its name and middle, and its counts.
var names: Array[String] = []
var middles: Array[Vector3] = []
var food: Array[int] = []
var food_total: Array[int] = []
var kits: Array[int] = []
var kits_total: Array[int] = []
## The zone he is in now (-1: no zones at all).
var current := -1
## Which zone is the grove (-1 with no zones), and its heart.
var grove := -1
var heart := Vector3.ZERO


static func place(world: World) -> Zones:
	var zones := Zones.new()
	zones.name = "Zones"
	zones.world = world
	var found := []
	for name: String in world.markers:
		if name.begins_with("zone_"):
			found.append([name.get_slice("_", 1).to_int(), name.get_slice("_", 2), (world.markers[name] as Transform3D).origin])
	found.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	for zone: Array in found:
		zones.names.append(String(zone[1]) if zone[1] != "" else "Zone %d" % (int(zone[0]) + 1))
		zones.middles.append(zone[2])
	if not zones.names.is_empty():
		zones.heart = (world.markers["grove_heart"] as Transform3D).origin if world.markers.has("grove_heart") else Vector3.ZERO
		zones.grove = zones.names.size()
		zones.names.append("Grove")
		zones.middles.append(zones.heart)
	var count := zones.names.size()
	for list: Array in [zones.food, zones.food_total, zones.kits, zones.kits_total]:
		list.resize(count)
		list.fill(0)
	world.add_child(zones)
	if count == 0:
		return zones
	# What there is to find in each: the Crumbs out now, what the cans hold, the lost kits
	for node in world.get_children():
		if node is Pickup and (node as Pickup).kind == Pickup.Kind.CRUMB:
			zones._count_food(node as Pickup)
		elif node is TrashCan:
			var zone := zones.zone_of((node as Node3D).global_position)
			if zone >= 0:
				zones.food_total[zone] += (node as TrashCan).holds
	if world.lost_kits:
		for kit in world.lost_kits.lost:
			var zone := zones.zone_of(kit.home)
			if zone >= 0:
				zones.kits_total[zone] += 1
			kit.set_meta(&"zone", zone)
		world.lost_kits.changed.connect(func(_home: int, _total: int) -> void: zones._recount_kits())
	return zones


## The zone `at` is in: the grove near its heart, else the side whose middle is nearest; -1 with no zones.
func zone_of(at: Vector3) -> int:
	if middles.is_empty():
		return -1
	if Vector2(at.x - heart.x, at.z - heart.z).length() < GROVE_RADIUS:
		return grove
	var best := -1
	var nearest := INF
	for k in grove:
		var d := Vector2(at.x - middles[k].x, at.z - middles[k].z).length()
		if d < nearest:
			nearest = d
			best = k
	return best


## A Crumb out: counted in its zone, and when taken, counted as found there.
func _count_food(crumb: Pickup) -> void:
	var zone := zone_of(crumb.global_position if crumb.is_inside_tree() else crumb.position)
	if zone < 0:
		return
	food_total[zone] += 1
	crumb.taken.connect(func(_p: Pickup) -> void:
		food[zone] += 1
		changed.emit())


## A Crumb that came later (out of a can): already counted in its zone's total by the can; counted when taken.
func spilled(crumb: Pickup) -> void:
	var zone := zone_of(crumb.position)
	if zone >= 0:
		crumb.taken.connect(func(_p: Pickup) -> void:
			food[zone] += 1
			changed.emit())


func _recount_kits() -> void:
	kits.fill(0)
	for member in world.lost_kits.villagers.members:
		if member.has_meta(&"zone") and not member in world.lost_kits.lost and not member in world.lost_kits.following:
			var zone: int = member.get_meta(&"zone")
			if zone >= 0:
				kits[zone] += 1
	changed.emit()


func _physics_process(_delta: float) -> void:
	if world.player == null:
		return
	# (whoever is played: him, or the bird he is playing as)
	var bird := BirdPlayer.active(world)
	var now := zone_of(bird.global_position if bird else world.player.global_position)
	if now != current:
		current = now
		changed.emit()
