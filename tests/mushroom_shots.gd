extends SceneTree
## Every MushroomGen preset (GameCommon mushrooms) in a row, three seeds each, then two from four sides and close up;
## prints each one's triangles. In a window:
##   godot --path . --audio-driver Dummy --resolution 1280x720 -s res://tests/mushroom_shots.gd -- --out=<dir>

var out := "user://mushroom_shots"
var camera: Camera3D


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.substr(6)
	DirAccess.make_dir_recursive_absolute(out)
	var stage := Node3D.new()
	root.add_child(stage)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(0.55, 0.66, 0.74)
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color(0.55, 0.55, 0.6)
	stage.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.9, 0.6, 0.0)
	stage.add_child(sun)
	var ground := MeshInstance3D.new()
	ground.mesh = PlaneMesh.new()
	(ground.mesh as PlaneMesh).size = Vector2(20.0, 20.0)
	var dirt := StandardMaterial3D.new()
	dirt.albedo_color = Color(0.3, 0.36, 0.22)
	ground.material_override = dirt
	stage.add_child(ground)
	camera = Camera3D.new()
	camera.fov = 40.0
	stage.add_child(camera)
	var names := MushroomGen.names()
	for i in names.size():
		for s in 3:
			var gen := MushroomGen.preset(names[i])
			gen.seed = 1 + s
			var shown := MeshInstance3D.new()
			shown.mesh = gen.mesh()
			shown.position = Vector3((i - names.size() * 0.5) * 0.45, 0.0, s * 0.45)
			# (a shelf on a post, as on a trunk)
			if gen.cap_shape == MushroomGen.Cap.SHELF:
				var post := MeshInstance3D.new()
				post.mesh = BoxMesh.new()
				(post.mesh as BoxMesh).size = Vector3(0.3, 0.6, 0.05)
				post.position = shown.position + Vector3(0.0, 0.3, -0.025)
				stage.add_child(post)
				shown.position.y += 0.1
			stage.add_child(shown)
			if s == 0:
				print("%-16s %4d triangles" % [names[i], shown.mesh.surface_get_array_index_len(0) / 3])
	_shoot.call_deferred(names.size())


func _snap(file: String, from: Vector3, at: Vector3) -> void:
	camera.position = from
	camera.look_at(at)
	for _i in 4:
		await process_frame
	root.get_texture().get_image().save_png(out.path_join(file))


func _shoot(many: int) -> void:
	var middle := Vector3(-0.2, 0.08, 0.45)
	await _snap("all_front.png", middle + Vector3(0.0, 1.4, 3.8), middle)
	await _snap("all_above.png", middle + Vector3(0.0, 4.2, 1.2), middle)
	# Close up on the first few and the last few, from four sides
	for pair: Array in [[0, "a"], [many - 4, "b"]]:
		var at := Vector3((int(pair[0]) + 1.5 - many * 0.5) * 0.45, 0.07, 0.45)
		for side: Array in [["front", Vector3(0, 0.35, 1.3)], ["right", Vector3(1.3, 0.35, 0)], ["back", Vector3(0, 0.35, -1.3)], ["left", Vector3(-1.3, 0.35, 0)]]:
			await _snap("close_%s_%s.png" % [pair[1], side[0]], at + side[1], at)
	print("SHOTS ", out)
	quit()
