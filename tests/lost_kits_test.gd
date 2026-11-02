extends SceneTree
## The lost kits (LostKits): two set down near him with markers of their own; walking up to one sends it home to the
## grove, the count goes up, and it stays put until found. Prints PASSED or FAILED. Headless:
##   godot --headless --path . --audio-driver Dummy --fixed-fps 60 -s res://tests/lost_kits_test.gd

var failures: Array[String] = []


func _initialize() -> void:
	var world: World = (load("res://scenes/world1.tscn") as PackedScene).instantiate()
	root.add_child(world)
	_run.call_deferred(world)


func _check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)
	if not ok:
		failures.append(what)


func _run(world: World) -> void:
	for _i in 20:
		await physics_frame
	var player := world.player
	var heart: Vector3 = world.markers["grove_heart"].origin if world.markers.has("grove_heart") else player.global_position
	# (out past the grove, on the ground there)
	var spot := heart + Vector3(14.0, 0.0, 0.0)
	var ground := world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(spot + Vector3.UP * 30.0, spot + Vector3.DOWN * 30.0, 1))
	if not ground.is_empty():
		spot = ground.position
	var markers := {"grove_heart": Transform3D(Basis.IDENTITY, heart),
		"kit_0": Transform3D(Basis.IDENTITY, spot), "kit_1": Transform3D(Basis.IDENTITY, spot + Vector3(0.0, 0.5, 3.0))}
	var kits := LostKits.place(world, markers, world.get_node(^"Villagers") as Villagers, player)
	var told := []
	kits.changed.connect(func(home: int, total: int) -> void: told.append([home, total]))
	_check(kits.total == 2 and kits.lost.size() == 2, "two lost kits out")
	var kit: Villager = kits.lost[0]
	for _i in 240:
		await physics_frame
	_check(kit.global_position.distance_to(spot) < 1.5, "a lost kit keeps to its spot (%.2f m off)" % kit.global_position.distance_to(spot))
	# (shut in a cage: going up to it is not enough; three hits of his tail break it open)
	player.global_position = kit.global_position + Vector3(0.0, 0.2, 0.9)
	for _i in 10:
		await physics_frame
	_check(kit in kits.lost and kit.has_meta(&"cage"), "caged, it is not found by going up to it")
	var cage: Cage = kit.get_meta(&"cage")
	for _hit in Cage.HITS:
		cage.tail_hit(player.global_position, Vector3(0.0, 2.0, -6.0))
	for _i in 10:
		await physics_frame
	_check(not is_instance_valid(cage), "three hits break the cage")
	_check(kit in kits.following and kit.leader == player and kits.found == 0 and told.is_empty(), "found, it follows him (not home yet)")
	_check(kits.rider == kit and kit.global_position.distance_to(player.global_position) < 0.8, "a kit climbs onto his back (%.2f m from him)" % kit.global_position.distance_to(player.global_position))
	# (he walks it home: it comes after him, and counts once it is in the grove)
	player.global_position = heart + Vector3(0.0, 0.3, 0.0)
	var home := false
	for _i in 900:
		await physics_frame
		if kits.found == 1:
			home = true
			break
	_check(home and told == [[1, 2]] and kit.home == heart and kit.leader == null, "led into the grove, it is home: 1 of 2")
	print("PASSED" if failures.is_empty() else "FAILED: " + ", ".join(failures))
	quit()
