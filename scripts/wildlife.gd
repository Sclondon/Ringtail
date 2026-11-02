class_name Wildlife
extends Node
## The skunks, badgers and rabbits (built 2026-11-01 in the raccoon's style, CritterRig) out on the town's lawns:
## the user, 2026-11-02, "where's the skunks and badgers and rabbits etc?". Their part in the game is still not
## decided, so they only live there (Claude's pick, a placeholder): each keeps to a patch of lawn about its home.
## Rabbits graze, then hop off a few metres, and bolt from the raccoon when he comes near; badgers trundle about,
## stopping to dig; skunks waddle, and turn their backs on him, tails up, when he is close. (The fox is a hazard:
## Hazards.)
##
##   Wildlife.place(world, lawn, player)

## How many of each.
const COUNTS := {"rabbit": 5, "badger": 2, "skunk": 2}
## How far from home each strays (metres), how fast it goes about and runs.
const RANGE := {"rabbit": 7.0, "badger": 9.0, "skunk": 8.0}
const PACE := {"rabbit": 2.6, "badger": 1.1, "skunk": 0.8}
const FLEE := {"rabbit": 5.5, "badger": 2.6, "skunk": 1.4}
## He is too near within this.
const SHY := 3.2

var player: Node3D
var _beasts: Array[Critter] = []
var _kinds: Array[String] = []
var _homes: Array[Vector3] = []
var _goals: Array[Vector3] = []
var _waits: Array[float] = []
var _rng := RandomNumberGenerator.new()


static func place(world: Node3D, lawn: TownGrass, hero: Node3D) -> Wildlife:
	var life := Wildlife.new()
	life.name = "Wildlife"
	life.player = hero
	life._rng.seed = 11
	world.add_child(life)
	for kind: String in COUNTS:
		for _k in COUNTS[kind]:
			var home := lawn.random_spot(life._rng)
			if home == Vector3.INF:
				continue
			var beast := Critter.make(kind)
			beast.name = "%s%d" % [kind.capitalize(), life._beasts.size()]
			beast.position = home + Vector3.UP * 0.3
			beast.rotation.y = life._rng.randf() * TAU
			world.add_child(beast)
			life._beasts.append(beast)
			life._kinds.append(kind)
			life._homes.append(home)
			life._goals.append(home)
			life._waits.append(life._rng.randf_range(0.5, 4.0))
	return life


func _physics_process(delta: float) -> void:
	for k in _beasts.size():
		var beast := _beasts[k]
		if not is_instance_valid(beast):
			continue
		var kind := _kinds[k]
		var at := beast.global_position
		var from_him := Vector3(at.x - player.global_position.x, 0.0, at.z - player.global_position.z)
		var near := from_him.length() < SHY and absf(at.y - player.global_position.y) < 2.0
		if near and kind != "skunk":
			# (off, away from him, keeping near home if it can)
			var away := from_him.normalized()
			_goals[k] = at + away * 4.0 + (_homes[k] - at).limit_length(2.0) * 0.3
			_waits[k] = 0.0
			beast.drive = (_goals[k] - at).slide(Vector3.UP).normalized() * float(FLEE[kind])
			continue
		if near:
			# (the skunk stands its ground, its back to him)
			beast.drive = Vector3.ZERO
			beast.rotation.y = lerp_angle(beast.rotation.y, atan2(from_him.x, from_him.z), 1.0 - exp(-6.0 * delta))
			continue
		var to_goal := Vector3(_goals[k].x - at.x, 0.0, _goals[k].z - at.z)
		if to_goal.length() < 0.3 or _blocked(beast, to_goal):
			beast.drive = Vector3.ZERO
			_waits[k] -= delta
			if _waits[k] <= 0.0:
				# (somewhere else on its patch; a rabbit only hops a little way at a time)
				var reach: float = 2.5 if kind == "rabbit" else float(RANGE[kind])
				var a := _rng.randf() * TAU
				_goals[k] = _homes[k] + Vector3(cos(a), 0.0, sin(a)) * _rng.randf_range(0.5, reach)
				if kind == "rabbit":
					_goals[k] = at + (_goals[k] - at).limit_length(3.0)
				_waits[k] = _rng.randf_range(1.5, 5.0) if kind != "badger" else _rng.randf_range(2.5, 7.0)
			continue
		beast.drive = to_goal.normalized() * float(PACE[kind])


## Whether something solid is close ahead of it (it gives up on that goal and picks another).
func _blocked(beast: Critter, way: Vector3) -> bool:
	var from := beast.global_position + Vector3.UP * 0.25
	var query := PhysicsRayQueryParameters3D.create(from, from + way.normalized() * 0.5, 1)
	query.exclude = [beast.get_rid()]
	return not get_viewport().get_world_3d().direct_space_state.intersect_ray(query).is_empty()
