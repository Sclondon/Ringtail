extends SceneTree
## The yard dogs (HazardDog's looks) beside the raccoon for size, from four sides, then one galloping:
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
	var dogs: Array[Dog] = []
	for k in HazardDog.LOOKS.size():
		var look: Array = HazardDog.LOOKS[k]
		var dog := Dog.new()
		dog.coat_tint = look[0]
		dog.mange = 0.0
		dog.eyeshine = 0.2
		dog.variant = look[2]
		dog.fur_shells = 1
		dog.scale = Vector3.ONE * float(look[1])
		dog.position = Vector3(-4.5 + k * 1.5, 0.0, 0.0)
		dog.rotation.y = PI / 2
		stage.add_child(dog)
		HazardDog.kept(dog)
		dogs.append(dog)
	var raccoon: Node3D = (load("res://models/raccoon.glb") as PackedScene).instantiate()
	raccoon.position = Vector3(4.6, 0.0, 0.0)
	raccoon.rotation.y = PI / 2
	stage.add_child(raccoon)
	Toon.apply(raccoon)
	var eye := Camera3D.new()
	eye.fov = 40.0
	stage.add_child(eye)
	for _i in 20:
		await process_frame
	for side in 4:
		var a := TAU * side / 4.0
		eye.look_at_from_position(Vector3(sin(a) * 9.0, 2.2, cos(a) * 9.0), Vector3(0.0, 0.4, 0.0))
		await process_frame
		await _shot("row_%d" % side)
	# One galloping by, side on
	var runner := dogs[0]
	for frame in 4:
		for _i in 6:
			runner.position.z += 5.5 / 60.0
			runner.rotation.y = 0.0
			await process_frame
		eye.look_at_from_position(runner.position + Vector3(3.5, 0.9, 0.0), runner.position + Vector3.UP * 0.4)
		await _shot("gallop_%d" % frame)
	print("DOG SHOTS DONE ", out)
	quit()


func _shot(called: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [out, called])
