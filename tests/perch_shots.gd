extends SceneTree
## Two grown-ups up a giant fir (Villagers.firs; the user, 2026-11-02: "a couple big trees for npcs to be in ... leaf
## platforms to stand on"): going up the bark, then sat on the same platform. Prints the firs found. A window (kept
## off the screen):
##   godot --path . --audio-driver Dummy --fixed-fps 60 --resolution 1280x720 -s res://tests/perch_shots.gd -- --out=<dir>

var out := "user://perch_shots"


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.substr(6)
	DirAccess.make_dir_recursive_absolute(out)
	root.position = Vector2i(-3000, 0)
	var world: World = (load("res://scenes/world1.tscn") as PackedScene).instantiate()
	root.add_child(world)
	_run.call_deferred(world)


func _shot(called: String) -> void:
	for _i in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [out, called])


func _run(world: World) -> void:
	for _i in 30:
		await physics_frame
	var band := world.get_node(^"Villagers") as Villagers
	for fir in band.firs:
		print("FIR at %s, %d platforms" % [fir.global_position, (fir.get_meta(&"perches") as Array).size()])
	if band.firs.is_empty():
		print("NO FIRS")
		quit()
		return
	var adults := band.members.filter(func(m: Villager) -> bool: return m.home != Vector3.INF and not m.kit and not m.giant)
	var two: Array[Villager] = [adults[0], adults[1]]
	var fir: Node3D = band.firs[0]
	var perch: Vector3 = (fir.get_meta(&"perches") as Array)[0]
	for who in two:
		who.playmate = null
		# (both to the same platform, set down by the fir's foot)
		who._go(Villager.Doing.STAND, 30.0)
		who._begin_perch()
		who._tree = fir
		who._perch = perch
		who._out = Vector3(perch.x - fir.global_position.x, 0.0, perch.z - fir.global_position.z).normalized()
		who._climb_to = perch.y - fir.global_position.y
		who.global_position = fir.global_position + who._out * 2.0 + who._out.cross(Vector3.UP) * (0.6 if who == two[0] else -0.6) + Vector3.UP * 0.3
	var player := world.player
	player.global_position = fir.global_position + two[0]._out.rotated(Vector3.UP, 0.6) * 8.0 + Vector3.UP * 0.5
	var eye := Camera3D.new()
	eye.fov = 50.0
	world.add_child(eye)
	eye.make_current()
	var climbing_shot := false
	for _i in 3000:
		await physics_frame
		for who in two:
			who._napping = false
		if two[0]._t > 8.0 and two[0]._climb_phase == 5:
			two[0]._t = 8.0
		if not climbing_shot and two[0]._climb_phase == 1 and two[0].global_position.y - fir.global_position.y > 2.0:
			climbing_shot = true
			eye.look_at_from_position(two[0].global_position + two[0]._out.rotated(Vector3.UP, 0.7) * 4.0 + Vector3.UP * 0.5, two[0].global_position)
			await _shot("climbing")
		if two[0]._climb_phase == 5 and two[1]._climb_phase == 5:
			for _k in 120:
				await physics_frame
			eye.look_at_from_position(perch + two[0]._out.rotated(Vector3.UP, 1.2) * 5.0 + Vector3.UP * 1.8, perch + Vector3.UP * 0.3)
			await _shot("perched")
			eye.look_at_from_position(perch + two[0]._out * 6.0 + Vector3.UP * 0.8, perch + Vector3.UP * 0.3)
			await _shot("perched_out")
			print("PERCHED talk %.1f/%.1f listen %.1f/%.1f" % [two[0].rig._talk_w, two[1].rig._talk_w, two[0].rig._listen_w, two[1].rig._listen_w])
			break
	print("PERCH SHOTS DONE ", out)
	quit()
