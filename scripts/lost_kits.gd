class_name LostKits
extends Node
## The kits lost about the hill, to find and send home (the user, 2026-11-02: "there should be [20] kits to rescue,
## and they should end up back in the grove after you find them"). One at each `kit_<n>` marker: a kit (Villager)
## that keeps to its spot, and says it is lost when he comes near (Chatter). Reach it and it cheers, and is gone in a
## puff of dust, to come out of another in the grove, where it plays with the others from then on. `changed` tells
## the HUD how many are home.
##
##   LostKits.place(world, markers, villagers, player)

signal changed(home: int, total: int)

## How near he must come to find one.
const REACH := 1.2
## What the lost ones say, and what they say once home (Claude's placeholders).
const NAMES := ["Bean", "Socks", "Pebble", "Twig", "Mochi", "Button", "Clover", "Sprout", "Biscuit", "Fig",
		"Pippin", "Mitten", "Acorn", "Puddle", "Noodle", "Scamp", "Thistle", "Wren", "Dumpling", "Tuft"]
const LOST := ["I'm lost!", "I can't find the grove...", "Can you take me home?"]
const HOME := ["You found me! Thank you!", "Home again!", "Let's play!"]

var villagers: Villagers
var player: Player
var heart := Vector3.ZERO
var lost: Array[Villager] = []
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
		var kit := band._add(true, k + 3, at + Vector3.UP * 0.3)
		kit.stays = true
		kit.home = at
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
		if kit.global_position.distance_to(player.global_position) < REACH:
			_send_home(kit)


## Found: a cheer and a puff where it was, a puff in the grove where it comes out, and it plays there now.
func _send_home(kit: Villager) -> void:
	lost.erase(kit)
	found += 1
	_puff_at(kit.global_position)
	if kit.rig:
		kit.rig.express(&"happy", 2.5)
	var a := randf() * TAU
	var spot := heart + Vector3(cos(a), 0.0, sin(a)) * randf_range(1.5, 3.5)
	kit.velocity = Vector3.ZERO
	kit.global_position = spot + Vector3.UP * 0.3
	kit.stays = false
	kit.home = heart
	kit.say([kit.display_name] + HOME)
	# (a playmate among the grove's kits)
	for other in villagers.members:
		if other != kit and other.kit and other.home == heart and not other in lost:
			kit.playmate = other
			break
	_puff_at(spot)
	changed.emit(found, total)


func _puff_at(at: Vector3) -> void:
	var dust := player.get_node_or_null(^"CloudDust") as CloudDust
	if dust == null:
		return
	for k in 9:
		var a := TAU * k / 9.0
		var out := Vector3(cos(a), 0.0, sin(a))
		dust.puff(at + out * 0.15, out * 1.2 + Vector3.UP * 0.6, 0.14)
