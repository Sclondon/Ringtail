extends SceneTree
## Pictures of every animal to play (AnimalPlayer.ANIMALS) for the pause screen's Play as grid: each drawn as it is in
## the game, three-quarters on, on a clear background, into ui/faces/<animal>.png (128 x 128). Needs a window:
##   godot --path . --audio-driver Dummy -s res://tools/make_animal_faces.gd [-- fox frog ...]

const SIZE := 128


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://ui/faces"))
	var only: Array = Array(OS.get_cmdline_user_args())
	var stage := SubViewport.new()
	stage.size = Vector2i(SIZE * 2, SIZE * 2)
	stage.transparent_bg = true
	stage.own_world_3d = true
	stage.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(stage)
	var sky := WorldEnvironment.new()
	sky.environment = Environment.new()
	sky.environment.background_mode = Environment.BG_CLEAR_COLOR
	sky.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	sky.environment.ambient_light_color = Color(0.75, 0.78, 0.8)
	sky.environment.ambient_light_energy = 0.6
	stage.add_child(sky)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.9, 0.6, 0.0)
	sun.light_energy = 1.1
	stage.add_child(sun)
	var camera := Camera3D.new()
	camera.fov = 30.0
	stage.add_child(camera)
	camera.current = true
	# (a floor to stand on)
	var ground := StaticBody3D.new()
	var slab := CollisionShape3D.new()
	slab.shape = BoxShape3D.new()
	(slab.shape as BoxShape3D).size = Vector3(20.0, 0.2, 20.0)
	slab.position.y = -0.1
	ground.add_child(slab)
	stage.add_child(ground)
	for what: String in AnimalPlayer.ANIMALS:
		if not only.is_empty() and not what in only:
			continue
		# (on a body standing still, as when played, so its rig stands it up)
		var figure := AnimalPlayer.make_figure(what)
		var holder: Node3D
		if figure is CritterRig:
			var body := Critter.new()
			body.rig = figure
			body.kind = what
			holder = body
		else:
			holder = Node3D.new()
			holder.add_child(figure)
		holder.rotation.y = -0.6
		stage.add_child(holder)
		for _i in 20:
			await process_frame
		# Framed round what is drawn: its head end nearer, a little from above
		var box := AABB()
		var first := true
		for mesh: MeshInstance3D in holder.find_children("*", "MeshInstance3D", true, false):
			var part := mesh.global_transform * mesh.get_aabb()
			box = part if first else box.merge(part)
			first = false
		var middle := box.get_center()
		var reach := maxf(box.size.length() * 0.5, 0.1)
		camera.global_position = middle + Vector3(0.0, 0.35, 1.0).normalized() * reach / tan(deg_to_rad(camera.fov * 0.5)) * 0.62
		camera.look_at(middle)
		for _i in 3:
			await process_frame
		var picture := stage.get_texture().get_image()
		picture.resize(SIZE, SIZE, Image.INTERPOLATE_LANCZOS)
		picture.save_png("res://ui/faces/%s.png" % what)
		print("FACE %s" % what)
		holder.queue_free()
		await process_frame
	print("FACES DONE")
	quit()
