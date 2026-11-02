extends SceneTree
## The street lights (DayNight.find_street_lamps): on world1, its own `streetlamp_<n>` markers and `streetlamp` heads
## if the town has them, else three made up here (a lamp head over the ring road beside the south street). At night
## the heads glow sodium orange, a pool lies on the ground under each, and the nearest throws real light down; by
## day none of that. Prints PASSED or FAILED. Headless:
##   godot --headless --path . --audio-driver Dummy --fixed-fps 60 -s res://tests/street_light_test.gd
## In a window with `-- --out=<dir>` it also takes a picture of them at night.

var failures: Array[String] = []


func _initialize() -> void:
	var world: World = (load("res://scenes/world1.tscn") as PackedScene).instantiate()
	root.add_child(world)
	_run.call_deferred(world)


func _check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)
	if not ok:
		failures.append(what)


func _ground(world: World, at: Vector3) -> Vector3:
	var hit := world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(at + Vector3.UP * 20.0, at + Vector3.DOWN * 40.0, 1, [world.player.get_rid()]))
	return hit.position if not hit.is_empty() else at


## The ground under a lamp's lens: looked for from just under it (from over it the ray met the lamp's own head).
func _below(world: World, lens: Vector3) -> Vector3:
	var hit := world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(lens + Vector3.DOWN * 0.3, lens + Vector3.DOWN * 40.0, 1, [world.player.get_rid()]))
	return hit.position if not hit.is_empty() else lens


func _run(world: World) -> void:
	for _i in 20:
		await physics_frame
	var day := DayNight.current
	day.held = true
	var real := world.markers.keys().any(func(name: String) -> bool: return name.begins_with("streetlamp_"))
	if not real:
		# (a made-up yard of three lamps by the ring road: a head of material `streetlamp` 5 m up, the marker under its lens)
		var heart: Vector3 = world.markers["grove_heart"].origin
		var look := StandardMaterial3D.new()
		look.resource_name = "streetlamp"
		look.albedo_color = Color(0.9, 0.9, 0.85)
		for n in 3:
			var foot := _ground(world, heart + Vector3((n - 1) * 12.0, 0.0, 42.0))
			var lens := foot + Vector3.UP * 5.0
			world.markers["streetlamp_%d" % n] = Transform3D(Basis.IDENTITY, lens)
			var head := MeshInstance3D.new()
			var box := BoxMesh.new()
			box.size = Vector3(0.5, 0.15, 0.3)
			box.material = look
			head.mesh = box
			world.add_child(head)
			head.global_position = lens + Vector3.UP * 0.08
		day.find_street_lamps()
	print("street lights: %d (%s)" % [day._street_spots.size(), "the town's" if real else "made up"])
	_check(day._street_spots.size() >= 3 and not day._street_heads.is_empty(), "lamps and heads found (%d, %d heads)" % [day._street_spots.size(), day._street_heads.size()])
	for _i in 6:
		await process_frame
	_check(day._pools != null and day._pools.multimesh.instance_count == day._street_spots.size(), "a pool under every lamp")
	# (headless the renderer is a dummy that keeps no MultiMesh transforms: every pool reads back at 0, so this is only
	# checked in a window)
	if day._pools and DisplayServer.get_name() == "headless":
		print("skip the pools lie on the ground (headless: run it in a window to check)")
	elif day._pools:
		var worst := 0.0
		for n in day._street_spots.size():
			var pool := day._pools.multimesh.get_instance_transform(n).origin
			worst = maxf(worst, absf(pool.y - _below(world, day._street_spots[n]).y))
		_check(worst < 0.2, "the pools lie on the ground (off by %.2f m at most)" % worst)
	# Midnight, beside the first lamp
	var lens := day._street_spots[0]
	world.player.global_position = _ground(world, lens) + Vector3(1.0, 0.3, 0.0)
	day.set_hour(0.5)
	day._light_nearest_lamps()
	await process_frame
	var head: Material = day._street_heads[0]
	var glow: float = head.get_shader_parameter(&"emission") if head is ShaderMaterial else (head as BaseMaterial3D).emission_energy_multiplier
	_check(glow > 1.5, "at night the heads glow (%.2f)" % glow)
	_check(day._pools != null and day._pools.visible, "at night the pools show")
	var lit := day._lamps.filter(func(l: Light3D) -> bool: return l.visible and l.global_position.distance_to(lens) < 0.5)
	_check(not lit.is_empty() and (lit[0] as Light3D).light_color.is_equal_approx(DayNight.SODIUM), "the nearest lamp really lights, sodium orange, shining down")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			# (in a window: the lamps from across the road)
			var eye := Camera3D.new()
			world.add_child(eye)
			eye.look_at_from_position(lens + Vector3(0.0, -2.5, -9.0), lens + Vector3(0.0, -4.0, 0.0))
			eye.make_current()
			for _i in 20:
				await process_frame
			DirAccess.make_dir_recursive_absolute(arg.substr(6))
			root.get_texture().get_image().save_png(arg.substr(6).path_join("street_lights_night.png"))
			eye.queue_free()
			world.camera.make_current()
	day.set_hour(12.0)
	day._light_nearest_lamps()
	await process_frame
	glow = head.get_shader_parameter(&"emission") if head is ShaderMaterial else (head as BaseMaterial3D).emission_energy_multiplier
	_check(glow < 0.05 and not day._pools.visible and not day._lamps.any(func(l: Light3D) -> bool: return l.visible), "by day all off")
	print("PASSED" if failures.is_empty() else "FAILED: " + ", ".join(failures))
	quit()
