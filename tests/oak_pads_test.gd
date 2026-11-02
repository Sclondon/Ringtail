extends SceneTree
## The great oak's leaf pads (TreeGen leaf_pads): there are some, each is in the markers as a perch, and he dropped
## onto one stands on it. Headless:
##   godot --headless --path . --audio-driver Dummy --fixed-fps 60 -s res://tests/oak_pads_test.gd

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
	for _i in 30:
		await physics_frame
	var pads := world._pad_perches
	_check(pads.size() >= 3, "the great oak has leaf pads (%d)" % pads.size())
	var listed := 0
	for name: String in world.markers:
		if name.begins_with("npc_perch_") and (world.markers[name] as Transform3D).origin in pads:
			listed += 1
	_check(listed == pads.size(), "each is a perch for the villagers (%d)" % listed)
	var stood := 0
	for top in pads:
		world.player.global_position = top + Vector3.UP * 1.2
		world.player.velocity = Vector3.ZERO
		for _i in 60:
			await physics_frame
		var y := world.player.global_position.y
		if world.player.is_on_floor() and absf(y - top.y) < 0.35:
			stood += 1
		else:
			print("  pad at %s: he is at %.2f, on floor %s" % [top, y, world.player.is_on_floor()])
	_check(stood == pads.size(), "he stands on every pad (%d of %d)" % [stood, pads.size()])
	print("PASSED" if failures.is_empty() else "FAILED: " + ", ".join(failures))
	quit()
