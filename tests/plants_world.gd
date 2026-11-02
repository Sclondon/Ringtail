extends SceneTree
## The hill's plants (GrovePlants): ferns, flowers and brambles set out, in every zone, none on a road; standing in a
## bramble thicket hides him (Hazards.hidden). Headless:
##   godot --headless --path . --audio-driver Dummy --fixed-fps 60 -s res://tests/plants_world.gd
## In a window with -- --out=<dir> it also shoots them: the grove's woods, a lawn, a bramble, a road's verge.

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


func _process(_delta: float) -> bool:
	var world := root.get_node_or_null(^"World") as World
	if world and world.hud and world.hud.pause and world.hud.pause.is_open():
		world.hud.pause.close()
	return false


func _run(world: World) -> void:
	for _i in 30:
		await physics_frame
	var plants := world.get_node_or_null(^"GrovePlants") as GrovePlants
	_check(plants != null, "the plants are set out")
	if plants == null:
		_end()
		return
	var counts := plants.counts()
	print("PLANTS ferns/low %d, flower clumps %d, brambles %d, patches %d" % [counts.x, counts.y, counts.z, plants._patches.size()])
	_check(counts.x > 150 and counts.y > 60 and counts.z > 15, "ferns, flowers and brambles (%s)" % counts)
	# In every zone, and never on a road
	var zones_with := {}
	var off_grass := 0
	for cell: Vector2i in plants._patches:
		var data: Dictionary = plants._patches[cell]
		zones_with[data["zone"]] = true
		for kind: String in data["flowers"]:
			for where: Transform3D in data["flowers"][kind]:
				if plants._lawn.mask(Vector2(where.origin.x, where.origin.z)) < 0.5:
					off_grass += 1
	var per := {}
	for cell: Vector2i in plants._patches:
		var z: int = plants._patches[cell]["zone"]
		per[z] = per.get(z, 0) + 1
	print("PATCHES BY ZONE %s names %s" % [per, world.zones.names if world.zones else []])
	_check(world.zones == null or zones_with.size() >= world.zones.names.size(), "in every zone (%d of %d)" % [zones_with.size(), world.zones.names.size() if world.zones else 0])
	_check(off_grass == 0, "none on a road or a path (%d off the grass)" % off_grass)
	# Hidden in a thicket
	var thicket: Vector3 = GrovePlants._thickets[0]
	var him := world.player
	var spot := Vector2(thicket.x, thicket.y)
	him.global_position = Vector3(spot.x, plants._lawn.height(spot) + 0.3, spot.y)
	him.velocity = Vector3.ZERO
	for _i in 40:
		await physics_frame
	_check(GrovePlants.in_thicket(him.global_position) and Hazards.hidden(him), "in a bramble thicket he is hidden (he is %s, the thicket %s)" % [him.global_position, thicket])
	if out != "":
		await _shots(world, plants)
	_end()


func _end() -> void:
	print("PASSED" if failures.is_empty() else "FAILED: " + ", ".join(failures))
	quit()


func _shots(world: World, plants: GrovePlants) -> void:
	DirAccess.make_dir_recursive_absolute(out)
	world.hud.visible = false
	var camera := Camera3D.new()
	camera.fov = 55.0
	world.add_child(camera)
	camera.current = true
	var heart := plants._heart
	var him := world.player
	var views := {}
	var a := 0.7
	var wood := heart + Vector3(cos(a), 0.0, sin(a)) * Zones.GROVE_RADIUS * 0.7
	views["grove_woods"] = [wood + Vector3(0.0, 2.0, 0.0) - Vector3(cos(a), 0, sin(a)) * 6.0, wood + Vector3(0.0, 0.5, 0.0)]
	views["grove_lawn"] = [heart + Vector3(-8.0, 2.5, 8.0), heart + Vector3(4.0, 0.0, -4.0)]
	var t: Vector3 = GrovePlants._thickets[mini(5, GrovePlants._thickets.size() - 1)]
	var bramble := Vector3(t.x, plants._lawn.height(Vector2(t.x, t.y)), t.y)
	views["bramble"] = [bramble + Vector3(3.5, 2.0, 3.5), bramble + Vector3(0.0, 0.6, 0.0)]
	if world.markers.has("road_1_3"):
		var r: Vector3 = (world.markers["road_1_3"] as Transform3D).origin
		views["road"] = [r + Vector3(0.0, 4.0, 0.0), r + Vector3(10.0, 0.0, 10.0)]
	for name: String in views:
		him.global_position = views[name][1] + Vector3(1.0, 1.0, 1.0)
		for _i in 30:
			await process_frame
		camera.global_position = views[name][0]
		camera.look_at(views[name][1])
		for _i in 20:
			await process_frame
		root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, name])
