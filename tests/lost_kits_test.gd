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
	var spot := player.global_position + Vector3(6.0, 0.0, 0.0)
	var markers := {"grove_heart": Transform3D(Basis.IDENTITY, heart),
		"kit_0": Transform3D(Basis.IDENTITY, spot), "kit_1": Transform3D(Basis.IDENTITY, spot + Vector3(0.0, 0.0, 6.0))}
	var kits := LostKits.place(world, markers, world.get_node(^"Villagers") as Villagers, player)
	var told := []
	kits.changed.connect(func(home: int, total: int) -> void: told.append([home, total]))
	_check(kits.total == 2 and kits.lost.size() == 2, "two lost kits out")
	var kit: Villager = kits.lost[0]
	for _i in 240:
		await physics_frame
	_check(kit.global_position.distance_to(spot) < 1.5, "a lost kit keeps to its spot (%.2f m off)" % kit.global_position.distance_to(spot))
	player.global_position = kit.global_position + Vector3(0.6, 0.2, 0.0)
	for _i in 10:
		await physics_frame
	_check(kits.found == 1 and not kit in kits.lost and told == [[1, 2]], "found, it is home: 1 of 2")
	_check(kit.global_position.distance_to(heart) < 5.0 and kit.home == heart and not kit.stays, "it is in the grove now")
	print("PASSED" if failures.is_empty() else "FAILED: " + ", ".join(failures))
	quit()
