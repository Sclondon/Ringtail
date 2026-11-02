class_name LostKits
extends Node
## The raccoons lost about the hill, to find and lead home (the user, 2026-11-02: "there should be [20] kits to rescue,
## and they should end up back in the grove after you find them", then "it shouldn't just be kits to rescue, adult
## raccoons too": every `ADULT_EVERY`th is a grown-up). One at each `kit_<n>` marker: a kit or a grown-up (Villager)
## that keeps to its spot, and says it is lost when he comes near (Chatter). Each is shut in a Cage he has to break
## with his tail (the user, 2026-11-02, "they should be in cages you have to break like in rayman"); out, it cheers
## and follows him:
## he has to lead it home (the user, 2026-11-02, "you should have to guide the kits back to the grove"). In the grove
## it stays, and plays with the others from then on. `changed` tells the HUD how many are home.
##
##   LostKits.place(world, markers, villagers, player)

signal changed(home: int, total: int)

## How near he must come to find one.
const REACH := 1.2
## What the lost ones say, and what they say once home (Claude's placeholders).
const NAMES := ["Bean", "Socks", "Pebble", "Twig", "Mochi", "Button", "Clover", "Sprout", "Biscuit", "Fig",
		"Pippin", "Mitten", "Acorn", "Puddle", "Noodle", "Scamp", "Thistle", "Wren", "Dumpling", "Tuft"]
const LOST := ["I'm lost!", "I can't find the grove...", "Can you take me home?"]
const LOST_ADULT := ["Oh! Am I glad to see you.", "I went looking for one of the little ones and got turned round.", "Lead on, I'll keep up."]
## Every so many lost ones is a grown-up (Claude's pick).
const ADULT_EVERY := 4
const ADULT_NAMES := ["Old Moss", "Bramble", "Juniper", "Clem", "Rook"]
const FOLLOWING := ["You found me!", "Take me home? I'll stay right behind you."]
const HOME := ["Home again! Thank you!", "Let's play!"]
## How near the grove's heart a kit is home.
const HOME_REACH := 11.0

var villagers: Villagers
var player: Player
var heart := Vector3.ZERO
var lost: Array[Villager] = []
## Found, following him home.
var following: Array[Villager] = []
var found := 0
var total := 0


static func place(world: Node3D, markers: Dictionary, band: Villagers, hero: Player) -> LostKits:
	var kits := LostKits.new()
	kits.name = "LostKits"
	kits.villagers = band
	kits.player = hero
	kits.heart = (markers["grove_heart"] as Transform3D).origin if markers.has("grove_heart") else hero.global_position
	world.add_child(kits)
	var k := 0
	while markers.has("kit_%d" % k):
		var at: Vector3 = (markers["kit_%d" % k] as Transform3D).origin
		var grown := k % ADULT_EVERY == ADULT_EVERY - 1
		var kit := band._add(not grown, k + 3, at + Vector3.UP * 0.3)
		kit.stays = true
		kit.home = at
		# (shut in a cage, to be broken open)
		var cage := Cage.new()
		cage.position = at
		cage.dust = hero.get_node_or_null(^"CloudDust") as CloudDust
		world.add_child(cage)
		# (it stays in the cage: the cage's walls are not in its way)
		kit.add_collision_exception_with(cage)
		cage.broken.connect(kits._found.bind(kit))
		kit.set_meta(&"cage", cage)
		if grown:
			kit.say([ADULT_NAMES[(k / ADULT_EVERY) % ADULT_NAMES.size()]] + LOST_ADULT)
		else:
			kit.say([NAMES[k % NAMES.size()]] + LOST)
		kits.lost.append(kit)
		k += 1
	kits.total = kits.lost.size()
	return kits


func _physics_process(_delta: float) -> void:
	if player == null:
		return
	for kit in lost.duplicate():
		if not is_instance_valid(kit) or kit.dead:
			continue
		# (one with no cage, found by going up to it)
		if not kit.has_meta(&"cage") and kit.global_position.distance_to(player.global_position) < REACH:
			_found(kit)
	for kit in following.duplicate():
		if not is_instance_valid(kit) or kit.dead:
			following.erase(kit)
			continue
		if Vector2(kit.global_position.x - heart.x, kit.global_position.z - heart.z).length() < HOME_REACH:
			_home(kit)


## Found: a cheer, and it follows him.
func _found(kit: Villager) -> void:
	if not kit in lost:
		return
	kit.remove_meta(&"cage")
	lost.erase(kit)
	following.append(kit)
	_puff_at(kit.global_position)
	if kit.rig:
		kit.rig.express(&"happy", 2.5)
	kit.stays = false
	kit.leader = player
	kit.say([kit.display_name] + FOLLOWING)
	kit._choose()


## Led into the grove: it stays, and plays with the others.
func _home(kit: Villager) -> void:
	following.erase(kit)
	found += 1
	if kit.rig:
		kit.rig.express(&"happy", 2.5)
	kit.leader = null
	kit.home = heart
	kit.say([kit.display_name] + HOME)
	# (a playmate among the grove's kits)
	for other in villagers.members:
		if kit.kit and other != kit and other.kit and other.home == heart and not other in lost and not other in following:
			kit.playmate = other
			break
	kit._choose()
	changed.emit(found, total)


func _puff_at(at: Vector3) -> void:
	var dust := player.get_node_or_null(^"CloudDust") as CloudDust
	if dust == null:
		return
	for k in 9:
		var a := TAU * k / 9.0
		var out := Vector3(cos(a), 0.0, sin(a))
		dust.puff(at + out * 0.15, out * 1.2 + Vector3.UP * 0.6, 0.14)
