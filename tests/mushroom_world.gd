extends SceneTree
## The hill's mushrooms (GroveMushrooms): how many and where, each patch in a zone, and the far ones hidden when he is
## on the far side. With -- --out=<dir> (in a window) shots of the wood ring and a ridge.
##   godot --headless --path . --audio-driver Dummy --fixed-fps 60 -s res://tests/mushroom_world.gd
##   godot --path . --audio-driver Dummy --resolution 1280x720 -s res://tests/mushroom_world.gd -- --out=<dir>

var failures: Array[String] = []
var out := ""


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.substr(6)
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
	var mushrooms := world.get_node_or_null(^"GroveMushrooms") as GroveMushrooms
	_check(mushrooms != null, "the mushrooms are out")
	if mushrooms:
		var patches := mushrooms.get_child_count()
		var zones := {}
		for cell: Vector2i in mushrooms._patches:
			zones[mushrooms._patches[cell]["zone"]] = true
		_check(mushrooms.count() > 60, "%d clusters in %d patches, zones %s" % [mushrooms.count(), patches, zones.keys()])
		var heart: Vector3 = world.markers["grove_heart"].origin
		if out != "":
			DirAccess.make_dir_recursive_absolute(out)
			var cam := Camera3D.new()
			world.add_child(cam)
			cam.current = true
			for shot: Array in [["wood", Vector3(0, 1.2, 19.5), Vector3(0, 0.2, 25.0)], ["wood2", Vector3(19.5, 1.0, 0), Vector3(25, 0.2, 2.0)],
					["roots", Vector3(-12, 1.0, -14), Vector3(-17, 0.3, -20)], ["ridge", Vector3(50, 2.0, 50), Vector3(62, 0.0, 62)]]:
				var from: Vector3 = heart + shot[1]
				var to: Vector3 = heart + shot[2]
				from.y = maxf(from.y, (mushrooms._lawn.height(Vector2(from.x, from.z)) if mushrooms._lawn.mask(Vector2(from.x, from.z)) > 0.5 else heart.y) + float(shot[1].y))
				to.y = (mushrooms._lawn.height(Vector2(to.x, to.z)) if mushrooms._lawn.mask(Vector2(to.x, to.z)) > 0.5 else heart.y) + float(shot[2].y)
				world.player.global_position = from - Vector3.UP * 0.8
				cam.global_position = from
				cam.look_at(to)
				for _i in 20:
					await process_frame
				cam.global_position = from
				cam.look_at(to)
				await process_frame
				root.get_texture().get_image().save_png(out.path_join("%s.png" % shot[0]))
		# He goes down the far side of one face: the patches of the opposite face are hidden
		if world.zones and world.zones.grove > 1:
			var far_side := world.zones.middles[0]
			world.player.global_position = far_side + Vector3.UP * 2.0
			for _i in 60:
				await physics_frame
			var opposite := (world.zones.current + 2) % world.zones.grove
			var hidden := 0
			var there := 0
			for cell: Vector2i in mushrooms._patches:
				if mushrooms._patches[cell]["zone"] == opposite:
					there += 1
					hidden += 0 if (mushrooms._shown[cell] as Node3D).visible else 1
			_check(there == 0 or hidden == there, "in %s, %d of %s's %d patches hidden" % [world.zones.names[world.zones.current], hidden, world.zones.names[opposite], there])
	print("PASSED" if failures.is_empty() else "FAILED: " + ", ".join(failures))
	quit()
