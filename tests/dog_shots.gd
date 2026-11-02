extends SceneTree
## The yard dogs (HazardDog.BREEDS on YardDog) beside the raccoon for size, from four sides; each face close up,
## glad; one snarling; then one galloping:
##   godot --path . --audio-driver Dummy --fixed-fps 60 --resolution 1280x720 -s res://tests/dog_shots.gd -- --out=<dir>
## Needs a window (kept off the screen).

var out := "user://dog_shots"


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
	sun.shadow_enabled = true
	stage.add_child(sun)
	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.background_mode = Environment.BG_COLOR
	world.environment.background_color = Color(0.55, 0.72, 0.9)
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color(0.6, 0.6, 0.65)
	stage.add_child(world)
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(60, 60)
	floor_mesh.mesh = plane
	var green := StandardMaterial3D.new()
	green.albedo_color = Color(0.35, 0.55, 0.25)
	floor_mesh.material_override = green
	stage.add_child(floor_mesh)
	# The dogs in a row, the raccoon at the end for size
	var dogs: Array[YardDog] = []
	for k in HazardDog.BREEDS.size():
		var kind: Array = HazardDog.BREEDS[k]
		var dog := YardDog.new()
		dog.breed = kind[0]
		dog.scale = Vector3.ONE * float(kind[1])
		dog.position = Vector3(-4.0 + k * 1.6, 0.0, 0.0)
		dog.rotation.y = PI / 2
		dog.friendly = true
		stage.add_child(dog)
		dogs.append(dog)
	var raccoon: Node3D = (load("res://models/raccoon.glb") as PackedScene).instantiate()
	raccoon.position = Vector3(4.2, 0.0, 0.0)
	raccoon.rotation.y = PI / 2
	stage.add_child(raccoon)
	Toon.apply(raccoon)
	var eye := Camera3D.new()
	eye.fov = 40.0
	stage.add_child(eye)
	for _i in 30:
		await process_frame
	for side in 4:
		var a := TAU * side / 4.0
		eye.look_at_from_position(Vector3(sin(a) * 9.0, 2.2, cos(a) * 9.0), Vector3(0.0, 0.4, 0.0))
		await process_frame
		await _shot("row_%d" % side)
	# Each face, close, from its front-quarter
	for dog in dogs:
		var head := dog.rig.jaw_tip() if dog.rig else dog.global_position
		var ahead := dog.global_basis.z.normalized()
		var aside := dog.global_basis.x.normalized()
		eye.look_at_from_position(head + ahead * 0.55 + aside * 0.3 + Vector3.UP * 0.12, head - ahead * 0.08 + Vector3.UP * 0.02)
		await process_frame
		await _shot("face_%s" % dog.breed)
	# One snarling, to see the teeth only come then
	dogs[1].friendly = false
	dogs[1].snarling = true
	for _i in 20:
		await process_frame
	var jaw := dogs[1].rig.jaw_tip()
	eye.look_at_from_position(jaw + dogs[1].global_basis.z * 0.5 + Vector3.UP * 0.1, jaw)
	await process_frame
	await _shot("snarl")
	dogs[1].snarling = false
	# One galloping by, side on
	var runner := dogs[0]
	for frame in 4:
		for _i in 6:
			runner.position.z += 5.4 / 60.0
			runner.rotation.y = 0.0
			await process_frame
		eye.look_at_from_position(runner.position + Vector3(3.0, 0.8, 0.0), runner.position + Vector3.UP * 0.35)
		await process_frame
		await _shot("gallop_%d" % frame)
	print("DOG SHOTS DONE ", out)
	quit()


func _shot(called: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [out, called])
