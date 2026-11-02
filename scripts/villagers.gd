class_name Villagers
extends Node3D
## The other raccoons of the town (the user, 2026-11-02: "There should be other raccons in the center of the grove
## to talk to", "kits and adults", "And there should be other raccons just running around the map doing stuff"):
## a gathering at the grove's heart, grown-ups standing and sitting about while their kits play tag round them,
## each with a word for the hero; and a few out in the town going round their haunts, one with a kit at its heels.
## Walk up to one with something to say and "Talk to <name>" shows (TalkBox, as in Gloaming).
##
##   Villagers.place(world, markers, player)    # in World._ready, once the player is in
##
## Where: the marker `grove_heart` (else just south of the great tree on the hilltop), and the markers `haunt_<n>`
## in order (else the pavements round the ring road). Their looks, sizes and lines are Claude's placeholders.

## Grown-up and kit sizes (the hero is 1).
const ADULT := [1.0, 0.94, 1.04, 0.97]
const KIT := 0.5
## A kit's head and middle against a grown-up's: bigger and rounder.
const KIT_HEAD := 1.4
const KIT_MIDDLE := Vector3(1.15, 1.0, 1.15)
const TINTS := [
	{"fur": Color(0.5, 0.47, 0.45), "tan": Color(0.57, 0.53, 0.5)},
	{"fur": Color(0.58, 0.5, 0.42), "tan": Color(0.66, 0.56, 0.45)},
	{"fur": Color(0.44, 0.41, 0.4), "tan": Color(0.52, 0.48, 0.46)},
	{"fur": Color(0.55, 0.52, 0.5), "tan": Color(0.62, 0.58, 0.55)},
	{"fur": Color(0.62, 0.55, 0.47), "tan": Color(0.7, 0.61, 0.5)},
]
## Who each at the grove is and what it says (Claude's placeholders: names, and hello-level chatter, no lore).
const GROVE_LINES := [
	["Old Grey", "Oh, hello! Back from the town already?", "Mind the cars on the ring road. They never look where they're going."],
	["Dozy", "Shh. I'm resting my eyes.", "...", "Fine. Hello."],
	["Gobbler", "Have you seen what the people leave out by the shops? Pizza!", "Whole slices! Some of them barely bitten."],
	["Pip", "Tag! You're it!", "...Aw, you're too big to play."],
	["Tumble", "Can you really spin your tail like that?", "Show me again! Again!"],
	["Nutmeg", "I found an acorn. It's mine.", "You can look at it, though."],
]
## And out in the town, the grown-ups going about.
const TOWN_LINES := [
	["Binsley", "Busy busy. Lots of bins to see to.", "Catch you later!"],
	["Lookout", "Keep an eye on the sky. The hawk's about."],
	["Hazel", "This one's with me. Say hello, little one."],
]

var player: Player
var members: Array[Villager] = []
var talk: TalkBox


static func place(world: Node3D, markers: Dictionary, hero: Player) -> void:
	var band := Villagers.new()
	band.name = "Villagers"
	band.player = hero
	world.add_child(band)
	band.talk = TalkBox.new()
	band.talk.villagers = band
	band.add_child(band.talk)

	# At the grove's heart: three grown-ups about it, three kits playing round them
	var heart: Vector3 = (markers["grove_heart"] as Transform3D).origin if markers.has("grove_heart") \
			else Vector3(0.5, (markers["check_top"] as Transform3D).origin.y if markers.has("check_top") else 7.1, 3.5)
	var spot := 0
	for k in 3:
		var a := TAU * k / 3 + 0.4
		var adult := band._add(false, k, heart + Vector3(cos(a), 0.4, sin(a)) * 1.3)
		adult.home = heart + Vector3(cos(a), 0.0, sin(a)) * 1.3
		adult.say(GROVE_LINES[spot])
		spot += 1
	var kits: Array[Villager] = []
	for k in 3:
		var a := TAU * k / 3 + 1.4
		var young := band._add(true, k + 2, heart + Vector3(cos(a), 0.4, sin(a)) * 2.3)
		young.home = heart
		young.say(GROVE_LINES[spot])
		spot += 1
		kits.append(young)
	# (two play tag; the third sometimes, with whichever)
	kits[0].playmate = kits[1]
	kits[1].playmate = kits[0]
	kits[0].chasing = true
	kits[2].playmate = kits[0]

	# Out in the town: going round the haunts, each starting at a different one
	var route := band._route(markers)
	var spread := [0, route.size() / 3, route.size() * 2 / 3]
	for k in 3:
		var at: int = spread[k]
		var goer := band._add(false, k + 1, route[at] + Vector3.UP * 0.4)
		goer.route = route
		goer.leg = at
		goer.say(TOWN_LINES[k])
		if k == 2:
			var young := band._add(true, k + 3, route[at] + Vector3(0.6, 0.4, 0.0))
			young.parent = goer


func _add(kit: bool, look: int, at: Vector3) -> Villager:
	var member := Villager.new()
	member.name = ("Kit%d" if kit else "Raccoon%d") % members.size()
	member.villagers = self
	member.kit = kit
	var rig := RaccoonRig.new()
	rig.name = "Rig"
	rig.dusty = false
	rig.key_poses = false
	rig.cap_hand = false
	# (kits go about on all fours; grown-ups stand, and drop to all fours to run)
	rig.always_on_fours = kit
	rig.scale = Vector3.ONE * (KIT if kit else ADULT[look % ADULT.size()])
	rig.look = {"colours": TINTS[look % TINTS.size()]}
	member.rig = rig
	member.position = at
	member.rotation.y = randf() * TAU
	add_child(member)
	if kit:
		_kit_shape(rig)
	members.append(member)
	return member


## A kit's big head and round middle: the bones' rest made bigger (the rig keeps a bone's rest size in every pose).
static func _kit_shape(rig: RaccoonRig) -> void:
	var skeleton := rig._skeleton
	for bone: String in ["head", "spine"]:
		var index := skeleton.find_bone(bone)
		if index < 0:
			continue
		var rest := skeleton.get_bone_rest(index)
		var size := Vector3.ONE * KIT_HEAD if bone == "head" else KIT_MIDDLE
		skeleton.set_bone_rest(index, Transform3D(rest.basis.scaled_local(size), rest.origin))


## The haunts to go round: the town's `haunt_<n>` markers in order, else the pavements either side of the ring road.
func _route(markers: Dictionary) -> Array[Vector3]:
	var route: Array[Vector3] = []
	var k := 0
	while markers.has("haunt_%d" % k):
		route.append((markers["haunt_%d" % k] as Transform3D).origin)
		k += 1
	if route.size() >= 3:
		return route
	route.clear()
	for side in [0, 1]:
		k = 0
		while markers.has("walk_%d_%d" % [side, k]):
			route.append((markers["walk_%d_%d" % [side, k]] as Transform3D).origin)
			k += 1
	if route.size() < 3:
		for a in 12:
			route.append(Vector3(cos(TAU * a / 12.0), 0.0, sin(TAU * a / 12.0)) * 30.0)
	return route


## How hard `member` is pushed away from the others close to it.
func apart(member: Villager) -> Vector3:
	var push := Vector3.ZERO
	var room := 0.45 if member.kit else 0.8
	for other in members:
		if other == member or other.dead:
			continue
		var gap := member.global_position - other.global_position
		gap.y = 0.0
		var d := gap.length()
		if d < room:
			push += (gap / maxf(d, 0.01)) * (room - d) / room
	return push


## The nearest danger within `reach` of `at`, or Vector3.INF (as the hero's band run from).
func threat_near(at: Vector3, reach: float) -> Vector3:
	var best := Vector3.INF
	var nearest := reach
	for group: StringName in Squad.DANGERS:
		for node in get_tree().get_nodes_in_group(group):
			var thing := node as Node3D
			if thing == null:
				continue
			var d := thing.global_position.distance_to(at)
			if d < nearest:
				nearest = d
				best = thing.global_position
	return best

