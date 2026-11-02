extends SceneTree
## Pictures of each hazard from the front, a side, behind and a quarter, one strip each:
##   godot --path . --audio-driver Dummy --fixed-fps 60 --resolution 960x540 -s res://tests/hazard_shots.gd -- --out=<dir>
## Needs a window (kept off the screen).

const SIZE := Vector2i(360, 360)
const HazardTest := preload("res://tests/hazard_test.gd")

var out := "user://hazard_shots"
var view: SubViewport
var eye: Camera3D
var player: Player


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.substr(6)
	DirAccess.make_dir_recursive_absolute(out)
	root.position = Vector2i(-3000, 0)
	var game := Node3D.new()
	root.add_child(game)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50.0, -35.0, 0.0)
	sun.shadow_enabled = true
	game.add_child(sun)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(0.45, 0.62, 0.85)
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color(0.55, 0.6, 0.7)
	game.add_child(environment)
	var floor_body := StaticBody3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(160.0, 2.0, 160.0)
	var collider := CollisionShape3D.new()
	collider.shape = shape
	floor_body.add_child(collider)
	var ground := MeshInstance3D.new()
	var plane := BoxMesh.new()
	plane.size = shape.size
	ground.mesh = plane
	ground.material_override = Toon.surface(Color(0.4, 0.6, 0.3))
	floor_body.add_child(ground)
	floor_body.position.y = -1.0
	game.add_child(floor_body)
	player = (load("res://raccoon.tscn") as PackedScene).instantiate()
	player.position = Vector3(0.0, 0.05, -60.0)
	game.add_child(player)
	Hazards.place(game, HazardTest.markers(), player)
	view = SubViewport.new()
	view.size = SIZE
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	eye = Camera3D.new()
	eye.fov = 40.0
	view.add_child(eye)
	_run.call_deferred()


func _frames(count: int) -> void:
	for _i in count:
		await process_frame


func _run() -> void:
	await _frames(90)
	var crow: HazardBird
	var hawk: HazardBird
	for node in get_nodes_in_group(&"hazards"):
		if node is HazardBird and node.kind == HazardBird.Kind.HAWK:
			hawk = node
		elif node is HazardBird and crow == null:
			crow = node
	var car: Node3D = get_nodes_in_group(&"cars")[0]
	var person: Node3D = get_nodes_in_group(&"people")[0]
	var fox: Node3D
	for node in get_nodes_in_group(&"hazards"):
		if node is HazardFox:
			fox = node
	# (everything stopped where it is, for the pictures)
	for node in get_nodes_in_group(&"hazards"):
		node.process_mode = Node.PROCESS_MODE_DISABLED
	await _strip("car", car, Vector3(0.0, 0.8, 0.0), 7.0)
	await _strip("person", person, Vector3(0.0, 1.0, 0.0), 4.5)
	await _strip("fox", fox, Vector3(0.0, 0.35, 0.0), 2.2)
	await _strip("crow_ground", crow, Vector3(0.0, 0.25, 0.0), 1.5)
	# A crow in flight and the hawk diving: moved near the ground to be seen, wings mid-beat
	crow.process_mode = Node.PROCESS_MODE_INHERIT
	crow.state = HazardBird.State.AWAY
	crow._target = crow.global_position + Vector3(0.0, 2.0, 0.0)
	await _frames(20)
	crow.process_mode = Node.PROCESS_MODE_DISABLED
	await _strip("crow_flying", crow, Vector3.ZERO, 1.8)
	hawk.global_position = Vector3(5.0, 3.0, -50.0)
	hawk.process_mode = Node.PROCESS_MODE_INHERIT
	await _frames(12)
	hawk.process_mode = Node.PROCESS_MODE_DISABLED
	await _strip("hawk", hawk, Vector3.ZERO, 3.2)
	print("HAZARD SHOTS DONE ", out)
	quit()


func _strip(name: String, subject: Node3D, aim: Vector3, distance: float) -> void:
	var sheet := Image.create(SIZE.x * 4, SIZE.y, false, Image.FORMAT_RGBA8)
	var at := subject.global_position + aim
	var yaw := subject.global_rotation.y
	if subject is Figure:
		yaw = (subject as Figure).facing_yaw
		at = (subject as Figure).visual_position + aim
	var angles := [0.0, PI * 0.5, PI, PI * 0.25]
	for k in angles.size():
		var a: float = yaw + angles[k]
		eye.global_position = at + Vector3(sin(a) * distance, distance * 0.3, cos(a) * distance)
		eye.look_at(at, Vector3.UP)
		await _frames(3)
		var image := view.get_texture().get_image()
		image.convert(Image.FORMAT_RGBA8)
		sheet.blit_rect(image, Rect2i(Vector2i.ZERO, SIZE), Vector2i(SIZE.x * k, 0))
	sheet.save_png(out.path_join(name + ".png"))
	print("SHOT ", name)
