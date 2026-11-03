class_name Villagers
extends Node3D
## The other raccoons of the town (the user, 2026-11-02: "There should be other raccons in the center of the grove
## to talk to", "kits and adults", "And there should be other raccons just running around the map doing stuff"):
## a gathering at the grove's heart, grown-ups standing and sitting about while their kits play tag round them,
## each with a word for the hero; and a few out in the town going round their haunts, one with a kit at its heels.
## Walk up to one with something to say and it says it in a speech bubble over its head (Chatter, as in Hemlock's Tower).
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
## A few characters: a very fat old one, a tall skinny one, a tiny runt of a kit (Claude's picks).
const OLD_GREY := {"size": 1.12, "girth": 1.55, "head": 1.05, "ears": 0.85, "marks": "frosted", "fur": "shaggy", "tail": [0.95, 1.35],
		"colours": {"fur": Color(0.55, 0.54, 0.53), "light": Color(0.88, 0.87, 0.85), "limb": Color(0.33, 0.32, 0.32), "tan": Color(0.66, 0.65, 0.63), "ring": Color(0.2, 0.2, 0.2)}}
const LANKY := {"size": 1.22, "girth": 0.8, "head": 0.95, "ears": 1.35, "fur": "sleek", "tail": [1.3, 0.85]}
const RUNT := {"size": 0.38, "girth": 1.0, "head": 1.12, "ears": 1.45, "fur": "soft"}
## The giant of the grove (the user, 2026-11-02: "1 giant Totoro-sized raccoon"; then "the totoro raccoon is too big
## now": about four times the size of the rest), round and fat, gentle and sleepy (Claude's picks for its look and
## its name), egg-shaped (EGG).
const GIANT := {"giant": true, "egg": true, "size": 4.0, "girth": 1.6, "head": 0.88, "ears": 0.9, "marks": "frosted", "fur": "soft", "tail": [1.1, 1.45],
		"colours": {"fur": Color(0.47, 0.42, 0.38), "light": Color(0.86, 0.82, 0.76), "limb": Color(0.27, 0.24, 0.22), "tan": Color(0.6, 0.55, 0.49), "ring": Color(0.19, 0.17, 0.16)}}
const GIANT_LINES := ["Old Mossback", "Mmmmm... hello... little one.", "...", "The grove is... warm... today.",
		"Mmm. Stay a while.", "Zzz... mm? Oh. Still here?", "The little ones... climb on me. I don't mind."]
const TINTS := [
	{"fur": Color(0.5, 0.47, 0.45), "tan": Color(0.57, 0.53, 0.5)},
	{"fur": Color(0.58, 0.5, 0.42), "tan": Color(0.66, 0.56, 0.45)},
	{"fur": Color(0.44, 0.41, 0.4), "tan": Color(0.52, 0.48, 0.46)},
	{"fur": Color(0.55, 0.52, 0.5), "tan": Color(0.62, 0.58, 0.55)},
	{"fur": Color(0.62, 0.55, 0.47), "tan": Color(0.7, 0.61, 0.5)},
]
## Who each at the grove is and what it says (Claude's placeholders: names, and hello-level chatter, no lore).
const GROVE_LINES := [
	["Old Grey", "Oh, hello! Back from the town already?", "Mind the cars on the road. They never look where they're going.",
			"When I was a kit, all this hill was trees. Well. More trees.", "The dogs down the hill bark worse than they bite. Mostly.",
			"If something's after you, get down in the tall grass and keep still.", "Wires are for walking. Don't let anyone tell you different.",
			"See the big mountain? It's always there. I find that restful.", "The shrine folk leave out rice cakes sometimes. Don't tell anyone I told you.",
			"Off you go, then. Bring something back for the little ones."],
	["Dozy", "Shh. I'm resting my eyes.", "...", "Fine. Hello.", "Is it night yet? It should be night.", "The owl's awake now, you know. I can tell.",
			"Wake me if anything good gets thrown out.", "That big tree's lovely and shady. Perfect for a nap.", "Mm. Five more minutes."],
	["Gobbler", "Have you seen what the people leave out by the shops? Pizza!", "Whole slices! Some of them barely bitten.",
			"The bins behind the bath house are the best. Warm, too.", "I had a whole doughnut once. I think about it every day.",
			"Apples from the gardens are fine. Pizza is better.", "Fish bones by the station! Crunchy!",
			"Don't eat the banana skins. Learn from me.", "If you find cheese, I want to hear about it."],
	["Pip", "Tag! You're it!", "...Aw, you're too big to play.", "Can you climb the drainpipes? I can't yet.", "I'm going to be the fastest when I'm big.",
			"Race you to the torii! ...I'll start running now.", "Hide and seek! Close your eyes! Okay, open them. ...Don't look in the grass.",
			"My tail's getting rings! Look! ...It's getting there."],
	["Tumble", "Can you really spin your tail like that?", "Show me again! Again!", "I tried to spin and fell over. Twice.",
			"How do you go so high off the wires? Teach me!", "When I'm big I'm going to fly with my tail. Like a seed.",
			"Mum says no jumping off the roofs. Did you jump off the roofs?", "Spin! Spin! Spin!"],
	["Nutmeg", "I found an acorn. It's mine.", "You can look at it, though.", "I'm keeping it for winter. Winter's ages away.",
			"There are more acorns under the big tree. Those ones are also mine.", "Do you collect things? I collect acorns.",
			"I counted my acorns. I have one.", "Maybe you can have the next one. Maybe."],
]
## And out in the town, the grown-ups going about.
const TOWN_LINES := [
	["Binsley", "Busy busy. Lots of bins to see to.", "Catch you later!", "Tuesday is the best bin day. Or is it Thursday.",
			"Knock a can over, have a look inside. That's the job.", "Watch the cats round the back gardens. Grumpy lot.",
			"The station bins get the commuters' lunches. Prime spot.", "No time to talk, no time at all. ...What's new with you?"],
	["Lookout", "Keep an eye on the sky. The hawk's about.", "The crows on the wires are mostly all talk. Mostly.",
			"See a big shadow on the ground? Run first, look up later.", "The owl takes the high poles by the far end. Steer clear.",
			"Dogs can't climb. Remember that.", "Tall grass, then up a pipe. That's how you lose anything.",
			"I've been watching that cloud for an hour. It's a good cloud."],
	["Hazel", "This one's with me. Say hello, little one.", "We're off to the gardens. The plums are nearly ripe.",
			"Keep to the walls when a car comes. Little ones first.", "She wants to climb everything. I wonder where she gets that.",
			"Have you seen the view from the top of the stairs? Lovely in the evening.", "We'll see you up at the grove later."],
]

## The raccoons of the world now (for `celebrate`).
static var current: Villagers

var player: Player
var members: Array[Villager] = []
var talk: Chatter


static func place(world: Node3D, markers: Dictionary, hero: Player) -> void:
	var band := Villagers.new()
	band.name = "Villagers"
	current = band
	band.player = hero
	world.add_child(band)
	band.talk = Chatter.new()
	band.talk.villagers = band
	band.add_child(band.talk)

	# At the grove's heart: three grown-ups about it, three kits playing round them
	var heart: Vector3 = (markers["grove_heart"] as Transform3D).origin if markers.has("grove_heart") \
			else Vector3(0.5, (markers["check_top"] as Transform3D).origin.y if markers.has("check_top") else 7.1, 3.5)
	# (the base is at the foot of the great oak, where the giant sits among its roots: the user, 2026-11-02, "the main base
	# should be at the base of a great big oak tree with gnarled roots, where the giant raccoon sits and snoozes")
	var oak := Vector3.INF
	if markers.has("great_oak"):
		oak = (markers["great_oak"] as Transform3D).origin
		var out := Vector3(heart.x - oak.x, 0.0, heart.z - oak.z)
		out = out.normalized() if out.length() > 0.5 else Vector3.BACK
		# (no nearer than 9.5 m: the oak is broad, and the giant sits between)
		if Vector2(heart.x - oak.x, heart.z - oak.z).length() < 9.5:
			heart = Vector3(oak.x, heart.y, oak.z) + out * 9.5
	var spot := 0
	for k in 3:
		var a := TAU * k / 3 + 0.4
		# (Old Grey a very fat old one)
		var adult := band._add(false, k, heart + Vector3(cos(a), 0.4, sin(a)) * 1.3, OLD_GREY if k == 0 else {})
		adult.home = heart + Vector3(cos(a), 0.0, sin(a)) * 1.3
		adult.say(GROVE_LINES[spot])
		spot += 1
	var kits: Array[Villager] = []
	for k in 3:
		var a := TAU * k / 3 + 1.4
		# (the third a tiny runt)
		var young := band._add(true, k + 2, heart + Vector3(cos(a), 0.4, sin(a)) * 2.3, RUNT if k == 2 else {})
		young.home = heart
		young.say(GROVE_LINES[spot])
		spot += 1
		kits.append(young)
	# The giant: sitting at the foot of the great tree (the biggest tree_ marker), facing the clearing
	var seat := heart + Vector3(6.0, 0.0, 0.0)
	var biggest := 149.0
	for name: String in markers:
		if name.begins_with("tree_") and name.get_slice_count("_") >= 4 and float(name.get_slice("_", 3)) > biggest:
			biggest = float(name.get_slice("_", 3))
			var trunk: Vector3 = (markers[name] as Transform3D).origin
			var toward := Vector3(heart.x - trunk.x, 0.0, heart.z - trunk.z).normalized()
			seat = trunk + toward * 4.5
	if oak != Vector3.INF:
		# (against the oak's trunk, among the roots, facing out over the base)
		var out := Vector3(heart.x - oak.x, 0.0, heart.z - oak.z).normalized()
		seat = oak + out * 4.0
	var mossback := band._add(false, 8, seat + Vector3.UP * 0.5, GIANT)
	mossback.home = seat
	mossback.say(GIANT_LINES)
	mossback.rotation.y = atan2(heart.x - seat.x, heart.z - seat.z)
	if oak != Vector3.INF:
		band._fit = [mossback, oak, heart]
	# (the leafy platforms up the giant firs, for them to climb up to and sit on: found once the physics has the trees)
	for name: String in markers:
		if name.begins_with("npc_perch_"):
			band._perch_marks.append((markers[name] as Transform3D).origin)
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
		# (Lookout a tall skinny one)
		var goer := band._add(false, k + 1, route[at] + Vector3.UP * 0.4, LANKY if k == 1 else {})
		goer.route = route
		goer.leg = at
		goer.say(TOWN_LINES[k])
		if k == 2:
			var young := band._add(true, k + 3, route[at] + Vector3(0.6, 0.4, 0.0))
			young.parent = goer


func _add(kit: bool, look: int, at: Vector3, special := {}) -> Villager:
	var member := Villager.new()
	# (its own build: seeded by who it is, so it is the same raccoon every time; `special` for the few characters)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(members.size() * 7919 + look * 131 + (1 if kit else 0))
	var build := _random_build(kit, rng)
	build.merge(special, true)
	member.name = ("Kit%d" if kit else "Raccoon%d") % members.size()
	member.villagers = self
	member.kit = kit
	member.giant = bool(build.get("giant", false))
	var rig := RaccoonRig.new()
	rig.name = "Rig"
	rig.dusty = false
	rig.key_poses = false
	rig.cap_hand = false
	# (one of the crowd: played from baked clips, tools/bake_raccoons.gd)
	rig.baked = true
	# (kits go about on all fours; grown-ups stand, and drop to all fours to run)
	rig.always_on_fours = kit
	rig.scale = Vector3.ONE * float(build.size)
	rig.look = {"colours": build.colours, "fur": build.fur, "marks": build.marks, "tail": build.tail}
	member.rig = rig
	member.position = at
	member.rotation.y = randf() * TAU
	add_child(member)
	_shape_bones(rig, kit, build)
	member.build = build
	members.append(member)
	return member


## A build of its own (the user, 2026-11-02: "different sized raccoons (big fat ones and little ones) and different ear
## sizes etc, more character variation"): size, girth, head, ears, tail, fur colour, marks and type, a wide but
## believable spread, a kit always plainly a kit. Claude's picks.
static func _random_build(kit: bool, rng: RandomNumberGenerator) -> Dictionary:
	var size := rng.randf_range(0.43, 0.58) if kit else 1.0 + rng.randfn(0.0, 0.1)
	var fur := Color.from_hsv(rng.randf_range(0.05, 0.11), rng.randf_range(0.06, 0.32), rng.randf_range(0.38, 0.68))
	return {
		"size": clampf(size, 0.38, 1.25),
		"girth": rng.randf_range(1.0, 1.3) if kit else clampf(1.05 + rng.randfn(0.0, 0.17), 0.8, 1.5),
		"head": rng.randf_range(0.92, 1.15),
		"ears": rng.randf_range(0.75, 1.5),
		"tail": [rng.randf_range(0.8, 1.3), rng.randf_range(0.8, 1.4)],
		"colours": {"fur": fur, "light": fur.lightened(0.45), "limb": fur.darkened(0.35), "tan": fur.lightened(0.15),
				"ring": fur.darkened(0.6)},
		"marks": ["plain", "plain", "plain", "frosted", "dark_tips", "streaked", "stippled"][rng.randi() % 7],
		"fur": ["rings", "rings", "rings", "soft", "shaggy", "sleek", "spiky", "wiry"][rng.randi() % 8],
	}


## Its build in its bones: head and ears, and the middle widened (a fat one round, a thin one narrow), a kit's head and
## middle bigger again. The bones' rest made so (the rig keeps a bone's rest size in every pose).
static func _shape_bones(rig: RaccoonRig, kit: bool, build: Dictionary) -> void:
	var skeleton := rig._skeleton
	if skeleton == null:
		return
	if build.get("egg", false):
		_egg_bones(skeleton, build)
		return
	var girth := float(build.girth)
	var sizes := {
		# (the head sits on the widened middle: its own size kept, not the middle's width too)
		"head": Vector3(1.0 / girth, 1.0, 1.0 / girth) * float(build.head) * (KIT_HEAD if kit else 1.0),
		"spine": Vector3(girth, 1.0, girth) * (KIT_MIDDLE if kit else Vector3.ONE),
		"ear_l": Vector3.ONE * float(build.ears), "ear_r": Vector3.ONE * float(build.ears),
	}
	for bone: String in sizes:
		var index := skeleton.find_bone(bone)
		if index < 0:
			continue
		var rest := skeleton.get_bone_rest(index)
		skeleton.set_bone_rest(index, Transform3D(rest.basis.scaled_local(sizes[bone]), rest.origin))


## The giant's egg (the user, 2026-11-02: "he needs to have more of an egg silhouette too"): widest at the belly,
## narrowing up to the shoulders, the head sat low on them with hardly a neck. Each bone's size as seen in the world
## (bone -> size); a bone's rest takes its size over its parent's, so the parent's does not carry on into it.
const EGG := {
	"hips": Vector3(2.0, 1.0, 1.8), "spine": Vector3(1.75, 1.25, 1.7), "chest": Vector3(1.05, 0.6, 1.05),
	"neck": Vector3(1.0, 0.5, 1.0), "upper_arm_l": Vector3(1.15, 1.15, 1.15), "upper_arm_r": Vector3(1.15, 1.15, 1.15),
	"thigh_l": Vector3(1.3, 1.0, 1.3), "thigh_r": Vector3(1.3, 1.0, 1.3), "shin_l": Vector3(1.2, 1.0, 1.2),
	"shin_r": Vector3(1.2, 1.0, 1.2), "tail_0": Vector3(1.1, 1.1, 1.1),
}


static func _egg_bones(skeleton: Skeleton3D, build: Dictionary) -> void:
	var sizes := EGG.duplicate()
	sizes["head"] = Vector3.ONE * float(build.head)
	sizes["ear_l"] = Vector3.ONE * float(build.head) * float(build.ears)
	sizes["ear_r"] = sizes["ear_l"]
	var seen: Array[Vector3] = []
	for index in skeleton.get_bone_count():
		var parent := skeleton.get_bone_parent(index)
		var above: Vector3 = seen[parent] if parent >= 0 else Vector3.ONE
		var bone := skeleton.get_bone_name(index)
		var size: Vector3 = sizes.get(bone, above)
		seen.append(size)
		var rest := skeleton.get_bone_rest(index)
		skeleton.set_bone_rest(index, Transform3D(rest.basis.scaled_local(size / above), rest.origin))


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
		# (two chatting stand close on purpose)
		if other == member.chat_with:
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



# --- The grown-ups chatting with one another (the user, 2026-11-02: "there needs to be a talking animation too so
# raccoon NPCs can talk to each other") ---

## What they say to one another, turn about (Claude's placeholders). Shown only when he is near, one bubble at a time.
const CHATS := [
	["Did you hear the dogs last night?", "All night! Not a wink of sleep.", "The beagle's the loudest.", "The bloodhound's the worst."],
	["They put the bins out early this week.", "Did they? Nobody tells me anything.", "I'm telling you now.", "...Thank you."],
	["The kits are getting so big.", "Eating us out of house and grove.", "Have you seen the pile, though?", "Growing nicely."],
	["Mind the new bus on the hill road.", "Big as a house!", "Bigger than a house.", "Bigger than two houses."],
	["Lovely evening.", "Lovely.", "Bit of wind.", "Bit of wind, yes."],
	["Have you tried the station bins?", "Too many people.", "Too many sandwiches, you mean.", "...Tomorrow, then."],
]

## The giant, the oak and the base, till it is set against the bark (once the trees are in the physics).
var _fit: Array = []
## The giant firs' perches: their markers, till the firs are found; then each fir (a node at its trunk's middle on the
## ground) with meta `perches` (the tops of its platforms).
var _perch_marks: Array[Vector3] = []
var firs: Array[Node3D] = []
var _chats: Array[Dictionary] = []
var _chat_wait := 5.0


## Whether another of them has gone up `tree` (or is on the way).
func tree_taken(tree: Node3D, asking: Villager) -> bool:
	for other in members:
		if other != asking and other.doing == Villager.Doing.CLIMB and other._tree == tree:
			return true
	return false


## A grown-up at the grove with nothing much on (for a game of tag, or a chat), or null.
func idle_adult(asking: Villager) -> Villager:
	for other in members:
		if other != asking and _free(other) and asking.global_position.distance_to(other.global_position) < 8.0:
			return other
	return null


func _free(who: Villager) -> bool:
	return not who.kit and not who.giant and not who.dead and not who.stays and who.leader == null and who.parent == null \
			and who.doing in [Villager.Doing.STAND, Villager.Doing.SIT, Villager.Doing.SNIFF, Villager.Doing.GROOM, Villager.Doing.STROLL]


func _physics_process(delta: float) -> void:
	if not _fit.is_empty():
		_fit_giant()
	if not _perch_marks.is_empty():
		_find_firs()
	_chat_wait -= delta
	if _chat_wait <= 0.0:
		_chat_wait = randf_range(6.0, 12.0)
		_try_chat()
	_turns(delta)


## Two grown-ups near each other with nothing much on: they meet and chat.
func _try_chat() -> void:
	for a in members:
		if not _free(a):
			continue
		for b in members:
			if b == a or not _free(b):
				continue
			if a.global_position.distance_to(b.global_position) < (6.0 if a.home != Vector3.INF else 4.0):
				start_chat(a, b)
				return


func start_chat(a: Villager, b: Villager) -> void:
	var middle := (a.global_position + b.global_position) * 0.5
	var across := Vector3(b.global_position.x - a.global_position.x, 0.0, b.global_position.z - a.global_position.z)
	across = across.normalized() if across.length() > 0.05 else Vector3.RIGHT
	# (time to walk up to each other; the chat's own while starts when they meet: _turns)
	var seconds := 15.0
	for pair: Array in [[a, b, -1.0], [b, a, 1.0]]:
		var who: Villager = pair[0]
		who.chat_with = pair[1]
		who.chat_spot = middle + across * 0.45 * float(pair[2])
		who._go(Villager.Doing.CHAT, seconds)
	a.speaking = true
	b.speaking = false
	_chats.append({"a": a, "b": b, "turn": randf_range(1.8, 2.8), "line": 0, "words": CHATS[randi() % CHATS.size()]})


## A chat broken off (one of them took fright): both go back to what they were doing.
func end_chat(who: Villager) -> void:
	var other := who.chat_with
	for each: Villager in [who, other]:
		if each and is_instance_valid(each):
			each.chat_with = null
			each.speaking = false
			if each.doing == Villager.Doing.CHAT and each != who:
				each._choose()


## Turns in the chats: each says a bit, then the other. If he is near the nearest chat and no one is talking to him,
## what they say shows over them.
func _turns(delta: float) -> void:
	var nearest: Dictionary = {}
	var best := 7.0
	for chat in _chats.duplicate():
		var a: Villager = chat.a
		var b: Villager = chat.b
		if not is_instance_valid(a) or not is_instance_valid(b) or a.chat_with != b or a.doing != Villager.Doing.CHAT:
			_chats.erase(chat)
			continue
		var d := player.global_position.distance_to((a.global_position + b.global_position) * 0.5) if player else INF
		if d < best:
			best = d
			nearest = chat
	for chat in _chats:
		var a: Villager = chat.a
		var b: Villager = chat.b
		# (they only start once both are there)
		if not (a._at(a.chat_spot, 0.3) and b._at(b.chat_spot, 0.3)):
			continue
		# (and from then it runs its while: walking up to each other is not the chat)
		if not chat.has("met"):
			chat.met = true
			var seconds := randf_range(6.0, 12.0)
			a._t = seconds
			b._t = seconds
		chat.turn = float(chat.turn) - delta
		var show := chat == nearest and talk and not talk.busy()
		if chat.turn <= 0.0 or (show and int(chat.line) == 0 and not chat.has("shown")):
			if chat.turn <= 0.0:
				chat.turn = randf_range(2.2, 3.2)
				a.speaking = not a.speaking
				b.speaking = not a.speaking
			var speaker: Villager = a if a.speaking else b
			var listener: Villager = b if a.speaking else a
			if show:
				chat.shown = true
				var words: Array = chat.words
				talk.bubble_of(speaker).say(words[int(chat.line) % words.size()], 2.6, speaker.display_name)
				talk.bubble_of(listener).hold = 0.0
				chat.line = int(chat.line) + 1


## Something brought home (a lost kit led back, the food pile grown): everyone at the grove celebrates a few seconds,
## turned to him, jumping with their arms up, the kits racing round, the giant awake and clapping (the user,
## 2026-11-02: "they should all celebrate when you bring stuff back").
static func celebrate(at: Vector3) -> void:
	if current == null or not is_instance_valid(current):
		return
	for member in current.members:
		if is_instance_valid(member) and member.home != Vector3.INF and member.global_position.distance_to(at) < 35.0:
			member.celebrate()


## Sets the giant with its back to the great oak's bark (the trunk's girth is the town's, and it grows: the user,
## 2026-11-02, "the giant tree not big enough"): a ray from the base to the trunk finds the bark, and it sits that far
## out plus its own width, on whatever is under it there (a root, the ground).
func _fit_giant() -> void:
	var giant: Villager = _fit[0]
	var oak: Vector3 = _fit[1]
	var heart: Vector3 = _fit[2]
	if not is_instance_valid(giant):
		_fit.clear()
		return
	var space := get_viewport().get_world_3d().direct_space_state
	var high := Vector3.UP * 2.5
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(heart + high, oak + high, 1, [giant.get_rid(), giant._solid.get_rid()]))
	_fit.clear()
	if hit.is_empty():
		return
	var out := Vector3(heart.x - oak.x, 0.0, heart.z - oak.z).normalized()
	# (out past the trunk's flare, to where the ground is about the base's level: a root or two is all right)
	var seat: Vector3 = hit.position + out * (0.25 * giant.rig.scale.x)
	seat.y = heart.y
	for step in 40:
		var at := seat + out * 0.25 * step
		var down := space.intersect_ray(PhysicsRayQueryParameters3D.create(at + Vector3.UP * 4.0, at + Vector3.DOWN * 6.0, 1, [giant.get_rid(), giant._solid.get_rid()]))
		if not down.is_empty() and down.position.y < heart.y + 0.7:
			seat = down.position
			break
	giant.global_position = seat + Vector3.UP * 0.1
	giant.home = seat
	giant.velocity = Vector3.ZERO
	giant.rotation.y = atan2(out.x, out.z)


## The giant firs (the user, 2026-11-02: "in between we need a couple big trees for npcs to be in. There should be like
## leaf platforms to stand on in the big trees"): under each `npc_perch_<n>` a ray out each way finds the nearest
## trunk, so each platform is put with its fir; a fir is a node at its trunk's middle, on the ground beside it.
const FIR_RADIUS := 1.1


func _find_firs() -> void:
	var space := get_viewport().get_world_3d().direct_space_state
	for perch in _perch_marks:
		var under := perch + Vector3.DOWN * 1.5
		var best := {}
		var best_d := 7.0
		var way := Vector3.ZERO
		for k in 16:
			var dir := Vector3.FORWARD.rotated(Vector3.UP, TAU * k / 16.0)
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(under, under + dir * 7.0, 1))
			# (bark stands upright: a platform's rim or underside is not the trunk)
			if not hit.is_empty() and absf((hit.normal as Vector3).y) < 0.2 and (hit.position as Vector3).distance_to(under) < best_d:
				best = hit
				best_d = (hit.position as Vector3).distance_to(under)
				way = dir
		if best.is_empty():
			continue
		# (in from the bark along its normal: a ray's way in is only one of sixteen; a platform whose ray finds its fir
		# poorly, high up, still goes with the fir nearest: they stand far apart)
		var normal := Vector3(best.normal.x, 0.0, best.normal.z)
		var middle: Vector3 = best.position - (normal.normalized() if normal.length() > 0.1 else -way) * FIR_RADIUS
		var fir: Node3D
		for other in firs:
			if Vector2(other.global_position.x - middle.x, other.global_position.z - middle.z).length() < 6.0:
				fir = other
		if fir == null:
			# (its foot: the ground beside the trunk, on the platform's side)
			var beside: Vector3 = best.position - way * 0.4
			var down := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(beside.x, perch.y - 2.0, beside.z), Vector3(beside.x, perch.y - 40.0, beside.z), 1))
			if down.is_empty():
				continue
			fir = Node3D.new()
			fir.name = "Fir%d" % firs.size()
			add_child(fir)
			fir.global_position = Vector3(middle.x, (down.position as Vector3).y, middle.z)
			fir.set_meta(&"perches", [] as Array[Vector3])
			firs.append(fir)
		(fir.get_meta(&"perches") as Array[Vector3]).append(perch)
	_perch_marks.clear()


## How many are up `fir` or on their way, and how many on `perch`.
func up_fir(fir: Node3D, perch := Vector3.INF) -> int:
	var count := 0
	for other in members:
		if other.doing == Villager.Doing.CLIMB and other._tree == fir and (perch == Vector3.INF or other._perch == perch):
			count += 1
	return count
