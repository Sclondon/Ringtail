extends SceneTree
## Pickups as in the game, close up: a row of Crumbs and a Bottlecap with their rim light and glints, then one
## taken, bursting (frames a moment apart):
##   godot --path . --audio-driver Dummy --fixed-fps 60 --resolution 1280x480 -s res://tests/pickup_shots.gd -- --out=<dir>
## Needs a window (kept off the screen).

var out := "user://pickup_shots"


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.substr(6)
	DirAccess.make_dir_recursive_absolute(out)
	root.position = Vector2i(-3000, 0)
	_run.call_deferred()


func _run() -> void:
	var stage := Node3D.new()
	root.add_child(stage)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50.0, 30.0, 0.0)
	stage.add_child(sun)
	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.background_mode = Environment.BG_COLOR
	world.environment.background_color = Color(0.3, 0.42, 0.25)
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color(0.6, 0.6, 0.65)
	stage.add_child(world)
	var pickups: Array[Pickup] = []
	for k in 6:
		var pickup := Pickup.make(Pickup.Kind.CRUMB if k < 5 else Pickup.Kind.CAP, Vector3(-2.0 + k * 0.8, 0.0, k * 0.37))
		stage.add_child(pickup)
		pickups.append(pickup)
	var eye := Camera3D.new()
	eye.fov = 35.0
	stage.add_child(eye)
	eye.look_at_from_position(Vector3(0.0, 1.0, 4.2), Vector3(0.0, 0.3, 0.9))
	for frame in 4:
		for _i in 25:
			await process_frame
		await _shot("row_%d" % frame)
	pickups[2].take()
	for frame in 4:
		for _i in 4:
			await process_frame
		await _shot("burst_%d" % frame)
	print("PICKUP SHOTS DONE ", out)
	quit()


func _shot(called: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [out, called])
