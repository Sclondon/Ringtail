extends SceneTree
## Pictures of the owls (placed as HazardOwl.place would) and a band of crows in World 1, as the game shows them (N64
## filter on): each from a little way off.
##   godot --path . --audio-driver Dummy --fixed-fps 60 --resolution 1280x720 -s res://tests/bird_world_shots.gd -- --out=<dir>
## Needs a window (kept off the screen).

var out := "user://bird_world_shots"
var world: World


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.substr(6)
	DirAccess.make_dir_recursive_absolute(out)
	root.position = Vector2i(-3000, 0)
	world = (load("res://scenes/world1.tscn") as PackedScene).instantiate()
	root.add_child(world)
	_run.call_deferred()


func _frames(count: int) -> void:
	for _i in count:
		await process_frame


func _shot(name: String) -> void:
	await _frames(3)
	root.get_texture().get_image().save_png(out.path_join(name + ".png"))
	print("SHOT ", name)


func _run() -> void:
	await _frames(30)
	if world.find_children("*", "HazardOwl", true, false).is_empty():
		HazardOwl.place(world, world.markers, world.player)
	await _frames(30)
	var camera := Camera3D.new()
	camera.fov = 40.0
	world.add_child(camera)
	camera.current = true
	var k := 0
	for owl: HazardOwl in world.find_children("*", "HazardOwl", true, false):
		owl._rest_left = 999.0
		var at := owl.perch
		var from := at + Vector3(2.0, 0.3, 2.0)
		camera.global_position = from
		camera.look_at(at + Vector3.UP * 0.3, Vector3.UP)
		owl.bird.look_at_point(from)
		await _frames(30)
		await _shot("owl%d" % k)
		k += 1
	var bands := world.find_children("*", "HazardCrows", true, false)
	if not bands.is_empty():
		var band := bands[0] as HazardCrows
		camera.global_position = band.home + Vector3(2.5, 1.2, 2.5)
		camera.look_at(band.home + Vector3.UP * 0.2, Vector3.UP)
		await _frames(60)
		await _shot("crows")
		band.crows[0].dive()
		await _frames(12)
		await _shot("crow_dive")
	print("SHOTS DONE ", out)
	quit()
