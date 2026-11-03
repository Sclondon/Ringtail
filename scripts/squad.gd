class_name Squad
extends Node3D
## The band of little raccoons about the hero (SquadRaccoon: the user, 2026-11-01, "a squad of raccoons that boid
## around you, that scurry about you with minds of their own"). Keeps their places on a loose ring about him (it
## turns slowly, and swings behind him as he runs), tells them what is near to sniff at and what to run from, and
## scatters them all when he is hurt.
##
##   Squad.place(world, player)      # in World._ready, once the player is in
##
## How many, how big and how coloured each is: `place`'s count, SIZES and TINTS (Claude's picks: placeholders).

const SIZES := [0.72, 0.64, 0.68, 0.6, 0.7, 0.66, 0.62]
## Each a little different: its fur, and its tail's lighter rings.
const TINTS := [
	{"fur": Color(0.55, 0.49, 0.44), "tan": Color(0.6, 0.53, 0.46)},
	{"fur": Color(0.46, 0.44, 0.44), "tan": Color(0.52, 0.5, 0.48)},
	{"fur": Color(0.6, 0.52, 0.42), "tan": Color(0.68, 0.57, 0.44)},
	{"fur": Color(0.5, 0.46, 0.48), "tan": Color(0.58, 0.52, 0.52)},
	{"fur": Color(0.42, 0.38, 0.35), "tan": Color(0.5, 0.45, 0.4)},
	{"fur": Color(0.58, 0.55, 0.52), "tan": Color(0.64, 0.6, 0.56)},
	{"fur": Color(0.52, 0.45, 0.4), "tan": Color(0.6, 0.5, 0.42)},
]
## Things to run from: these groups (the yard cats, hazards, whatever chases).
const DANGERS := [&"pursuers", &"cats", &"hazards", &"cars", &"people"]

var player: Player
var members: Array[SquadRaccoon] = []
var _ring := 0.0
var _hearts_were := -1


static func place(world: Node3D, hero: Player, count := 5) -> void:
	var squad := Squad.new()
	squad.name = "Squad"
	squad.player = hero
	world.add_child(squad)
	for k in count:
		var member := SquadRaccoon.new()
		member.name = "Squaddie%d" % k
		member.squad = squad
		member.index = k
		var rig := RaccoonRig.new()
		rig.name = "Rig"
		rig.always_on_fours = true
		# (played from baked clips, tools/bake_raccoons.gd)
		rig.baked = true
		rig.dusty = false
		rig.key_poses = false
		rig.cap_hand = false
		rig.scale = Vector3.ONE * SIZES[k % SIZES.size()]
		rig.look = {"colours": TINTS[k % TINTS.size()]}
		member.rig = rig
		var a := TAU * k / count
		member.position = hero.global_position + Vector3(cos(a), 0.2, sin(a)) * 1.5
		squad.add_child(member)
		squad.members.append(member)


func _ready() -> void:
	var game := get_tree().get_first_node_in_group(&"game")
	if game and game.has_signal(&"hearts_changed"):
		game.hearts_changed.connect(_on_hearts)


func _physics_process(delta: float) -> void:
	_ring = fposmod(_ring + delta * 0.25, TAU)


## Where member `index` is drawn to: a place on a loose ring about him, turning slowly; behind him as he runs.
func slot(index: int) -> Vector3:
	var count := maxi(members.size(), 1)
	var a := _ring + TAU * index / count
	var radius := 1.3 + 0.35 * sin(_ring * 3.0 + index * 1.7)
	var at := player.global_position + Vector3(cos(a), 0.0, sin(a)) * radius
	var going := Vector3(player.velocity.x, 0.0, player.velocity.z)
	return at - going * 0.35


## How hard `member` is pushed away from the others close to it (a level vector, larger the closer).
func apart(member: SquadRaccoon) -> Vector3:
	var push := Vector3.ZERO
	for other in members:
		if other == member or not is_instance_valid(other):
			continue
		var gap := member.global_position - other.global_position
		gap.y = 0.0
		var d := gap.length()
		if d < 0.8:
			push += (gap / maxf(d, 0.01)) * (0.8 - d) / 0.8
	return push


## Something near him for `member` to go and sniff at (food, a trash can), not one another is at; or null.
func something_to_sniff(near: Vector3, hero_at: Vector3, member: SquadRaccoon) -> Node3D:
	var choices: Array[Node3D] = []
	for group: StringName in [&"pickups", &"tail_hittable"]:
		for node in get_tree().get_nodes_in_group(group):
			var thing := node as Node3D
			if thing == null or thing is SquadRaccoon or thing.is_in_group(&"cats"):
				continue
			if thing.global_position.distance_to(hero_at) < 5.0 and thing.global_position.distance_to(near) < 6.0 \
					and absf(thing.global_position.y - near.y) < 0.8:
				choices.append(thing)
	for other in members:
		if other != member and other.mind == SquadRaccoon.Mind.SNIFF:
			choices.erase(other._sniff_at)
	return choices.pick_random() if not choices.is_empty() else null


## One of the band is dead: the rest close up the ring.
func lose(member: SquadRaccoon) -> void:
	members.erase(member)
	for k in members.size():
		members[k].index = k


## The nearest danger within `reach` of `at`, or Vector3.INF.
func threat_near(at: Vector3, reach: float) -> Vector3:
	var best := Vector3.INF
	var nearest := reach
	for group: StringName in DANGERS:
		for node in get_tree().get_nodes_in_group(group):
			var thing := node as Node3D
			if thing == null:
				continue
			var d := thing.global_position.distance_to(at)
			if d < nearest:
				nearest = d
				best = thing.global_position
	return best


func _on_hearts(count: int) -> void:
	# (he is hurt: they all scatter from where he is)
	if _hearts_were >= 0 and count < _hearts_were:
		for member in members:
			if is_instance_valid(member):
				member._scatter(player.global_position, 1.2)
	_hearts_were = count
