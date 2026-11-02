extends SceneTree
## Drives the raccoon through each move in the playground and photographs him from
## the front, his left, behind and a quarter, each move one strip:
##   godot --path . --audio-driver Dummy --fixed-fps 60 --resolution 960x540 -s res://tests/pose_shots.gd -- --out=<dir> [moves...]
## Needs a window (pictures cannot be taken headless); it is kept off the screen.

const SIZE := Vector2i(360, 400)
const MOVES := ["stand", "walk", "run", "sprint", "duckwalk", "duck", "jump", "glide", "whip", "spin"]

var out := "user://pose_shots"
var only: Array[String] = []
var player: Player
var view: SubViewport
var eye: Camera3D


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.substr(6)
		else:
			only.append(arg)
	DirAccess.make_dir_recursive_absolute(out)
	root.position = Vector2i(-3000, 0)
	var level: Node3D = load("res://scenes/playground.tscn").instantiate()
	root.add_child(level)
	view = SubViewport.new()
	view.size = SIZE
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	eye = Camera3D.new()
	eye.fov = 40.0
	view.add_child(eye)
	_run.call_deferred(level)


func _run(level: Node3D) -> void:
	await process_frame
	player = level.player
	for move: String in MOVES:
		if only.is_empty() or move in only:
			await _do(move)
	print("POSE SHOTS DONE ", out)
	quit()


func _frames(count: int) -> void:
	for _i in count:
		await physics_frame


func _release() -> void:
	for action: StringName in [&"move_up", &"duck", &"sprint", &"jump", &"tail"]:
		Input.action_release(action)


func _do(move: String) -> void:
	_release()
	player.global_position = Vector3(12.0, 0.05, -12.0)
	player.velocity = Vector3.ZERO
	await _frames(40)
	match move:
		"stand":
			await _frames(30)
		"walk":
			Input.action_press(&"move_up", 0.35)
			await _frames(70)
		"run":
			Input.action_press(&"move_up", 1.0)
			await _frames(40)
		"sprint":
			Input.action_press(&"move_up", 1.0)
			Input.action_press(&"sprint")
			await _frames(70)
		"duckwalk":
			Input.action_press(&"duck")
			await _frames(10)
			Input.action_press(&"move_up", 0.8)
			await _frames(60)
		"duck":
			Input.action_press(&"duck")
			await _frames(30)
		"jump":
			Input.action_press(&"jump")
			player._queue_jump()
			await _frames(16)
		"glide":
			Input.action_press(&"jump")
			player._queue_jump()
			await _frames(45)
		"whip":
			Input.action_press(&"tail")
			await _frames(9)
		"spin":
			Input.action_press(&"jump")
			player._queue_jump()
			await _frames(14)
			Input.action_release(&"jump")
			Input.action_press(&"tail")
			await _frames(11)
	await _strip(move)
	_release()


func _strip(move: String) -> void:
	var sheet := Image.create(SIZE.x * 4, SIZE.y, false, Image.FORMAT_RGBA8)
	var at := player.visual_position + Vector3.UP * 0.6
	var yaw := player.facing_yaw
	# (front, his left, behind, a quarter)
	var angles := [0.0, PI * 0.5, PI, PI * 0.25]
	for k in angles.size():
		var a: float = yaw + angles[k]
		eye.global_position = at + Vector3(sin(a) * 3.0, 0.5, cos(a) * 3.0)
		eye.look_at(at, Vector3.UP)
		for _f in 4:
			await process_frame
		var image := view.get_texture().get_image()
		image.convert(Image.FORMAT_RGBA8)
		sheet.blit_rect(image, Rect2i(Vector2i.ZERO, SIZE), Vector2i(SIZE.x * k, 0))
	sheet.save_png(out.path_join(move + ".png"))
	print("SHOT ", move)
