extends SceneTree
## Pictures of the climbable trees (GameCommon tree: "Climbing oak" and "Climbing maple"), each from four
## sides, and the raccoon standing on one of the oak's limbs, close, from two sides. Prints each tree's
## triangles, surfaces and collision shapes.
##   godot --path . --audio-driver Dummy --resolution 960x720 -s res://tests/tree_shots.gd -- --out=<dir>
## Needs a window (kept off the screen).

var out := "user://tree_shots"


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.substr(6)
	DirAccess.make_dir_recursive_absolute(out)
	root.position = Vector2i(-3000, 0)
	_run.call_deferred()


func _frames(count: int) -> void:
	for _i in count:
		await process_frame


func _shot(name: String, at: Vector3, look: Vector3, eye: Camera3D) -> void:
	eye.look_at_from_position(at, look, Vector3.UP)
	await _frames(4)
	root.get_texture().get_image().save_png(out.path_join(name + ".png"))
	print("SHOT ", name)


func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.6, 0.72, 0.85)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.6, 0.66, 0.76)
	env.environment.ambient_light_energy = 0.8
	world.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.light_energy = 1.4
	sun.shadow_enabled = true
	world.add_child(sun)
	sun.look_at_from_position(Vector3(-4, 10, 7), Vector3.ZERO, Vector3.UP)
	var ground := StaticBody3D.new()
	var plane := MeshInstance3D.new()
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(80, 80)
	plane.mesh = mesh
	var grass := StandardMaterial3D.new()
	grass.albedo_color = Color(0.38, 0.52, 0.28)
	plane.material_override = grass
	ground.add_child(plane)
	var floor := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(80, 2, 80)
	floor.shape = box
	floor.position.y = -1.0
	ground.add_child(floor)
	world.add_child(ground)
	var oak := TreeGen.preset("Climbing oak")
	var maple := TreeGen.preset("Climbing maple")
	var oak_body := oak.body()
	world.add_child(oak_body)
	var maple_body := maple.body()
	maple_body.position = Vector3(12.0, 0.0, 0.0)
	world.add_child(maple_body)
	for named: Array in [["Climbing oak", oak], ["Climbing maple", maple]]:
		var tree: TreeGen = named[1]
		var tris := 0
		var made := tree.mesh()
		for s in made.get_surface_count():
			tris += made.surface_get_array_index_len(s) / 3
		print("%s: %d triangles, %d surfaces (draws), %d collision shapes, %d walks, %.1f m high" % [named[0], tris, made.get_surface_count(),
			tree.shapes().size(), tree.walks().size(), tree.built_height])
	# The raccoon on the oak's third limb, half way along it, looking out along it
	var walk: PackedVector3Array = oak.walks()[4]
	var stand := walk[walk.size() / 2]
	var player: Player = (load("res://raccoon.tscn") as PackedScene).instantiate()
	world.add_child(player)
	player.global_position = stand + Vector3.UP * 0.1
	player.facing_yaw = atan2(stand.x, stand.z)
	var eye := Camera3D.new()
	eye.fov = 50.0
	world.add_child(eye)
	eye.current = true
	await _frames(40)
	print("raccoon on limb 2: on floor %s at %.2f m (limb top %.2f m)" % [player.is_on_floor(), player.global_position.y, stand.y])
	var middle := Vector3(0.0, 5.5, 0.0)
	for side: Array in [["front", Vector3(0, 3, 24)], ["right", Vector3(24, 3, 0)], ["back", Vector3(0, 3, -24)], ["left", Vector3(-24, 3, 0)]]:
		await _shot("oak_" + side[0], middle + side[1], middle, eye)
	var maple_mid := Vector3(12.0, 4.0, 0.0)
	for side: Array in [["front", Vector3(0, 4, 14)], ["right", Vector3(14, 4, 0)], ["back", Vector3(0, 4, -14)], ["left", Vector3(-14, 4, 0)]]:
		await _shot("maple_" + side[0], maple_mid + side[1], maple_mid, eye)
	var across := Vector3(stand.z, 0.0, -stand.x).normalized()
	var on := player.global_position + Vector3.UP * 0.5
	await _shot("on_limb_side", on + across * 3.2 + Vector3.UP * 0.8, on, eye)
	await _shot("on_limb_out", on + Vector3(stand.x, 0.0, stand.z).normalized() * 3.5 + Vector3.UP * 1.0, on, eye)
	await _shot("under_canopy", Vector3(4.0, 1.4, 5.0), Vector3(0.0, 5.0, 0.0), eye)
	print("TREE SHOTS DONE ", out)
	quit()
