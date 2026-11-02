extends SceneTree
## Yard dogs and hiding in tall grass, headless in World 1: a dog sees the raccoon, barks and chases; hidden down
## in tall grass he is lost to it (it casts about, then goes home); a cat does not stalk him hidden either.
##   godot --headless --path . --audio-driver Dummy --fixed-fps 60 -s res://tests/dog_test.gd

var world: World
var failures: Array[String] = []


func _initialize() -> void:
	world = (load("res://scenes/world1.tscn") as PackedScene).instantiate()
	root.add_child(world)
	_run.call_deferred()


func _check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)
	if not ok:
		failures.append(what)


func _frames(count: int) -> void:
	for _i in count:
		await physics_frame


func _run() -> void:
	await _frames(20)
	var player := world.player
	var lawn := TownGrass.current
	_check(lawn != null, "the lawn is grown")
	if lawn == null:
		_end()
		return
	# (everything else out of the way)
	for node in get_nodes_in_group(&"hazards"):
		if not node is HazardDog:
			node.process_mode = Node.PROCESS_MODE_DISABLED
	var dogs := get_nodes_in_group(&"hazards").filter(func(n: Node) -> bool: return n is HazardDog)
	_check(dogs.size() >= 2, "dogs in the town (%d)" % dogs.size())
	# A spot on open lawn well away from the grove, for him and a dog of our own
	var rng := RandomNumberGenerator.new()
	rng.seed = 4
	var spot := Vector3.INF
	for _try in 200:
		var s := lawn.random_spot(rng)
		if s != Vector3.INF and not Hazards.safe(s) and s.distance_to(Hazards.haven) > Hazards.HAVEN_RADIUS + 4.0:
			spot = s
			break
	_check(spot != Vector3.INF, "an open lawn out of the grove")
	if spot == Vector3.INF:
		_end()
		return
	for other in dogs:
		other.process_mode = Node.PROCESS_MODE_DISABLED
	# (put where it has a clear run at him: not over a wall, nor outside the play area)
	var start := spot + Vector3(4.0, 0.0, 0.0)
	for way: Vector3 in [Vector3(4, 0, 0), Vector3(-4, 0, 0), Vector3(0, 0, 4), Vector3(0, 0, -4)]:
		var q := PhysicsRayQueryParameters3D.create(spot + Vector3.UP * 0.3, spot + way + Vector3.UP * 0.3, 1)
		if world.get_world_3d().direct_space_state.intersect_ray(q).is_empty():
			start = spot + way
			break
	var dog := HazardDog.make(start, 9, player)
	world.add_child(dog)
	player.global_position = spot + Vector3.UP * 0.2
	player.velocity = Vector3.ZERO
	var chased := false
	for _i in 120:
		await physics_frame
		chased = chased or dog.state == HazardDog.State.CHASE or dog.state == HazardDog.State.LUNGE
	_check(chased, "a dog sees him, barks and gives chase (state %s)" % HazardDog.State.keys()[dog.state])
	var hearts_were := world.hearts
	var bitten := false
	for _i in 240:
		await physics_frame
		if world.hearts < hearts_were:
			bitten = true
			break
	_check(bitten, "its spring and snap bites him (hearts %d -> %d)" % [hearts_were, world.hearts])
	# (bitten, he is thrown: back on his spot, and settled)
	await _frames(60)
	player.global_position = spot + Vector3.UP * 0.2
	player.velocity = Vector3.ZERO
	await _frames(30)
	# Hidden: tall grass round where he stands
	lawn._tall.append(Vector3(player.global_position.x, player.global_position.z, 3.0))
	dog._rest = 0.0
	dog.global_position = player.global_position + Vector3(3.5, 0.3, 0.0)
	dog._go(HazardDog.State.CHASE)
	var lost := false
	for _i in 30:
		await physics_frame
		lost = lost or dog.state == HazardDog.State.SEARCH
	_check(Hazards.hidden(player) and lost, "hidden in tall grass, he is lost to the dog (hidden %s, state %s)" % [Hazards.hidden(player), HazardDog.State.keys()[dog.state]])
	var found := false
	for _i in 300:
		await physics_frame
		found = found or dog.state == HazardDog.State.CHASE
	_check(not found, "the dog does not find him again while he stays hidden")
	# A cat right by him does not stalk him hidden
	var cats := get_nodes_in_group(&"cats")
	if not cats.is_empty():
		var cat := cats[0] as YardCat
		cat.process_mode = Node.PROCESS_MODE_INHERIT
		cat.global_position = player.global_position + Vector3(0.0, 0.3, 2.5)
		cat.mode = YardCat.Mode.WANDER
		var stalked := false
		for _i in 120:
			await physics_frame
			stalked = stalked or cat.mode == YardCat.Mode.STALK or cat.mode == YardCat.Mode.POUNCE
		_check(not stalked, "a cat beside him does not stalk him hidden")
	dog.queue_free()
	_end()


func _end() -> void:
	print("PASSED" if failures.is_empty() else "FAILED: " + ", ".join(failures))
	quit()
