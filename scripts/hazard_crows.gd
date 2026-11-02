class_name HazardCrows
extends Node3D
## A little band of crows about one spot (a `crows_<n>` marker): HazardBirds that sit up on the wires and the roof
## ridges round it, now and then drop down to peck about on the ground, and fly up again (the user, 2026-11-02: "the
## crows should sit on roofs and wires etc", "and not necessarily be hostile"). Most bands leave him be: come near and
## they only take off for another perch. A `hostile` band (Claude's pick: every third) sends one at a time to
## dive-bomb him while he is near.

var home := Vector3.ZERO
var count := 4
var player: Player
var hostile := false
## How near he must be for a hostile band to go for him, and the wait between dives.
var notice := 7.0
var every := Vector2(1.8, 3.2)
## How far round home they look for places to sit.
var reach := 18.0

var crows: Array[HazardBird] = []
## Places to sit up high: points on wires and on roofs (found once the world's bodies are in the physics).
var perches: Array[Vector3] = []
var _wait := 2.0


func _ready() -> void:
	for k in count:
		var crow := HazardBird.new()
		crow.kind = HazardBird.Kind.CROW
		var a := TAU * k / count
		crow.home = home + Vector3(cos(a), 0.0, sin(a)) * 1.2
		crow.player = player
		crow.band = self
		add_child(crow)
		crows.append(crow)
	_find_perches.call_deferred()


func _find_perches() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	# On the wires: points along each near enough (not the ends, at the poles)
	for node in get_tree().get_nodes_in_group(&"tightropes"):
		var wire := node as Tightrope
		if wire == null or wire.reach_to(home) > reach:
			continue
		for t: float in [0.25, 0.4, 0.55, 0.7]:
			perches.append(wire.point_at_distance(wire.span() * t) + Vector3.UP * 0.03)
	# On the roofs: high level-ish faces under straight-down rays round home
	var space := get_world_3d().direct_space_state
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(home)
	for _k in 60:
		var a := rng.randf() * TAU
		var spot := home + Vector3(cos(a), 0.0, sin(a)) * rng.randf_range(2.0, reach)
		var query := PhysicsRayQueryParameters3D.create(spot + Vector3.UP * 30.0, spot + Vector3.DOWN * 10.0, 1)
		var hit := space.intersect_ray(query)
		if hit.is_empty() or not hit.collider is StaticBody3D:
			continue
		var at: Vector3 = hit.position
		if at.y > home.y + 2.5 and (hit.normal as Vector3).y > 0.55:
			perches.append(at + Vector3.UP * 0.02)
	# (and up they go)
	for crow in crows:
		crow.fly_to(next_spot(crow, true))


## Where `crow` goes next: another perch (most times, or always if `up`), or down onto the ground near home.
func next_spot(crow: HazardBird, up := false) -> Vector3:
	if perches.is_empty() or (not up and randf() < 0.3):
		return home + Vector3(randf_range(-2.0, 2.0), 0.0, randf_range(-2.0, 2.0))
	# (not where another already sits)
	for _try in 8:
		var spot: Vector3 = perches[randi() % perches.size()]
		var taken := false
		for other in crows:
			if other != crow and other.target_spot().distance_to(spot) < 0.5:
				taken = true
		if not taken:
			return spot
	return perches[randi() % perches.size()]


func _physics_process(delta: float) -> void:
	if player == null or not hostile:
		return
	_wait -= delta
	if _wait > 0.0 or player.global_position.distance_to(home) > notice or Hazards.unseen(player):
		return
	_wait = randf_range(every.x, every.y)
	crows.shuffle()
	for crow in crows:
		if crow.dive():
			return
