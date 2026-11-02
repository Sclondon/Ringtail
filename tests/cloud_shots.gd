extends SceneTree
## Pictures of the sky's puff clouds (GameCommon godot/puff-clouds) under Ringtail's dusk sky and sun (as
## World._environment makes them), from the ground looking across and looking up:
##   godot --path . --audio-driver Dummy --resolution 1280x720 -s res://tests/cloud_shots.gd -- --out=<dir>

var out := "user://cloud_shots"


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.substr(6)
	DirAccess.make_dir_recursive_absolute(out)
	root.position = Vector2i(-3000, 0)
	var scene := Node3D.new()
	root.add_child(scene)
	# (World._environment's sun and sky)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-28.0, 60.0, 0.0)
	sun.light_color = Color(1.0, 0.78, 0.58)
	sun.light_energy = 1.1
	scene.add_child(sun)
	var sky := ProceduralSkyMaterial.new()
	sky.sky_top_color = Color(0.22, 0.28, 0.52)
	sky.sky_horizon_color = Color(0.98, 0.62, 0.45)
	sky.ground_horizon_color = Color(0.6, 0.45, 0.4)
	sky.ground_bottom_color = Color(0.2, 0.18, 0.2)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = Sky.new()
	environment.sky.sky_material = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.55, 0.52, 0.7)
	var world := WorldEnvironment.new()
	world.environment = environment
	scene.add_child(world)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(120.0, 120.0)
	ground.mesh = plane
	scene.add_child(ground)
	var clouds := PuffClouds.add_to(scene, sun)
	print("puffs ", clouds.puffs)
	var camera := Camera3D.new()
	camera.fov = 70.0
	scene.add_child(camera)
	camera.current = true
	_shoot.call_deferred(camera)


func _shoot(camera: Camera3D) -> void:
	# Across towards the sun, across away from it, and up overhead
	var views := {"away": Vector3(10.0, 60.0, 0.0), "toward_sun": Vector3(10.0, 240.0, 0.0), "up": Vector3(70.0, 150.0, 0.0)}
	for name: String in views:
		camera.position = Vector3(0.0, 2.0, 0.0)
		camera.rotation_degrees = views[name]
		for _f in 4:
			await process_frame
		root.get_texture().get_image().save_png(out.path_join(name + ".png"))
		print("SHOT ", name)
	print("CLOUD SHOTS DONE ", out)
	quit()
