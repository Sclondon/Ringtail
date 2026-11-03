extends SceneTree
## A figure posed live beside the same figure played from its baked clips (BakedMotion), standing, walking and
## running, seen from the side; a strip of frames of each. In a window:
##   godot --path . --audio-driver Dummy --fixed-fps 60 --resolution 1280x720 -s res://tests/baked_compare.gd -- \
##       --out=<dir> [--maker=res://scripts/critter.gd] [--what=fox] [--size=1.0]

var _out := "user://baked_compare"
var _maker := "res://scripts/critter.gd"
var _what := "fox"
var _size := 1.0
var _bodies: Array[Node3D] = []
var _camera: Camera3D


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.get_slice("=", 1)
		elif a.begins_with("--maker="):
			_maker = a.get_slice("=", 1)
		elif a.begins_with("--what="):
			_what = a.get_slice("=", 1)
		elif a.begins_with("--size="):
			_size = float(a.get_slice("=", 1))
	DirAccess.make_dir_recursive_absolute(_out)
	var floor := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(60.0, 1.0, 900.0)
	shape.shape = box
	floor.add_child(shape)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(60.0, 900.0)
	ground.mesh = plane
	ground.position.y = 0.5
	floor.add_child(ground)
	floor.position.y = -0.5
	root.add_child(floor)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.9, 0.6, 0.0)
	root.add_child(sun)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.55, 0.62, 0.7)
	env.environment.ambient_light_color = Color(0.6, 0.6, 0.6)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	root.add_child(env)
	_camera = Camera3D.new()
	_camera.fov = 40.0
	root.add_child(_camera)
	var maker: Script = load(_maker)
	for k in 2:
		var body: Node3D = maker.call(&"make", _what)
		var rig: Variant = body.get(&"rig")
		if rig is CharacterRig:
			(rig as CharacterRig).baked = k == 1
			(rig as CharacterRig).process_mode = Node.PROCESS_MODE_ALWAYS
		# (its own thinking off, moved here by hand, as tools/bake_motion.gd does)
		body.process_mode = Node.PROCESS_MODE_DISABLED
		(body as CollisionObject3D).disable_mode = CollisionObject3D.DISABLE_MODE_KEEP_ACTIVE
		# (live on the right of the picture, baked on the left)
		body.position = Vector3(0.0, 0.1, -400.0 + 1.6 * _size * k)
		root.add_child(body)
		_bodies.append(body)
	_run.call_deferred()


func _process(_delta: float) -> bool:
	if _bodies.size() == 2 and is_instance_valid(_bodies[0]):
		var middle := (_bodies[0].global_position + _bodies[1].global_position) * 0.5
		_camera.global_position = middle + Vector3(4.2 * _size, 0.9 * _size, 0.0)
		_camera.look_at(middle + Vector3.UP * 0.3 * _size)
	return false


var _speed := 0.0


func _physics_process(_delta: float) -> bool:
	for body in _bodies:
		var moved := body as CharacterBody3D
		moved.velocity = Vector3(0.0, -0.1, _speed)
		moved.move_and_slide()
		if &"is_sprinting" in body:
			body.set(&"is_sprinting", _speed > float(body.get(&"run_speed")) * 0.7)
	return false


func _set_speed(speed: float) -> void:
	_speed = speed


func _run() -> void:
	print("BAKED figures: %d" % BakedMotion.count(self))
	var specs := [["stand", 0.0], ["walk", 1.0], ["trot", 2.5], ["run", 4.0]]
	if &"sit_progress" in _bodies[0]:
		specs.append(["sit", 0.0, "sit_progress"])
	for spec: Array in specs:
		_set_speed(spec[1])
		for body in _bodies:
			if spec.size() > 2:
				body.set(spec[2], 1.0)
		for _i in 150:
			await process_frame
		for shot in 4:
			for _i in 7:
				await process_frame
			await RenderingServer.frame_post_draw
			var image := root.get_texture().get_image()
			image.save_png("%s/%s_%s_%d.png" % [_out, _what, spec[0], shot])
	print("BAKED figures at the end: %d" % BakedMotion.count(self))
	quit()
