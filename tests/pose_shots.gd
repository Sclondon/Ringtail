extends SceneTree
## Drives the raccoon through each move in the playground and photographs him from
## the front, his left, behind and a quarter, each move one strip:
##   godot --path . --audio-driver Dummy --fixed-fps 60 --resolution 960x540 -s res://tests/pose_shots.gd -- --out=<dir> [moves...]
## Needs a window (pictures cannot be taken headless); it is kept off the screen.

const SIZE := Vector2i(360, 400)
const MOVES := ["stand", "walk", "run", "sprint", "duckwalk", "duck", "jump", "glide", "spin", "air_spin", "bound", "leap", "spin_film", "heli", "long_jump", "scurry_film", "walk_film", "sneak_film", "sneak", "idle_tall", "idle_lean", "idle_crack", "idle_stretch"]

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
	physics_frame.connect(_hold)
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


## Held actions, pressed again every step: the window is kept off the screen and Godot lets go of everything
## whenever it loses focus.
var _held := {}


func _press(action: StringName, strength := 1.0) -> void:
	_held[action] = strength
	Input.action_press(action, strength)


func _hold() -> void:
	for action: StringName in _held:
		Input.action_press(action, _held[action])
	# (and nothing else of his steered from outside: a gamepad in use elsewhere reaches this window too)
	for action: StringName in [&"move_left", &"move_right", &"move_up", &"move_down", &"jump", &"duck", &"tail", &"scurry"]:
		if not _held.has(action) and InputMap.has_action(action) and Input.is_action_pressed(action):
			Input.action_release(action)


func _release() -> void:
	_held.clear()
	(player.get_node(^"Scurry") as Scurry).button = false
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
		"idle_tall", "idle_lean", "idle_crack", "idle_stretch":
			# (one of the things he does standing about, held: RaccoonRig IDLES)
			var rig := player.get_node(^"Rig") as RaccoonRig
			rig._idle = StringName(move.substr(5))
			rig._idle_t = 0.0
			rig._idle_for = 99.0
			await _frames(40 if move == "idle_crack" else 70)
		"walk":
			_press(&"move_up", 0.35)
			await _frames(70)
		"run":
			_press(&"move_up", 1.0)
			await _frames(40)
		"sprint":
			_press(&"move_up", 1.0)
			_press(&"sprint")
			await _frames(70)
		"duckwalk":
			_press(&"duck")
			await _frames(10)
			_press(&"move_up", 0.8)
			await _frames(60)
		"duck":
			_press(&"duck")
			await _frames(30)
		"jump":
			_press(&"jump")
			player._queue_jump()
			await _frames(16)
		"glide":
			_press(&"jump")
			player._queue_jump()
			# (pressed again in the air: the twirl)
			await _frames(15)
			player._queue_jump()
			await _frames(30)
		"spin":
			_press(&"tail")
			await _frames(9)
		"spin_film":
			_press(&"tail")
			await _frames(1)
			await _filmstrip(move, 4)
			_release()
			return
		"heli":
			_press(&"jump")
			player._queue_jump()
			await _frames(15)
			player._queue_jump()
			await _frames(25)
			await _filmstrip(move, 2)
			_release()
			return
		"long_jump":
			_press(&"move_up", 1.0)
			await _frames(45)
			_press(&"duck")
			await _frames(3)
			player._queue_jump()
			await _frames(2)
			await _filmstrip(move, 4)
			_release()
			return
		"leap":
			_press(&"move_up", 1.0)
			await _frames(50)
			_press(&"jump")
			player._queue_jump()
			await _frames(3)
			await _filmstrip(move, 5)
			_release()
			return
		"bound":
			_press(&"move_up", 1.0)
			_press(&"sprint")
			await _frames(15)
			_recentre()
			await _frames(55)
			await _filmstrip(move)
			_release()
			return
		"scurry_film":
			(player.get_node(^"Scurry") as Scurry).button = true
			_press(&"move_up", 1.0)
			await _frames(15)
			_recentre()
			await _frames(55)
			await _filmstrip(move, 1, 12, 2.4, -0.2)
			_release()
			return
		"sneak":
			_press(&"move_up", 0.25)
			await _frames(70)
		"walk_film":
			_press(&"move_up", 0.6)
			await _frames(70)
			await _filmstrip(move, 3, 12, 3.0, 0.4)
			_release()
			return
		"sneak_film":
			_press(&"move_up", 0.25)
			await _frames(70)
			await _filmstrip(move, 5, 12, 3.0, 0.3)
			_release()
			return
		"air_spin":
			_press(&"jump")
			player._queue_jump()
			await _frames(14)
			_held.erase(&"jump")
			Input.action_release(&"jump")
			_press(&"tail")
			await _frames(11)
	await _strip(move)
	_release()


## `count` pictures (eight: about one bound) `gap` frames apart, from his left side, the camera keeping pace
## `distance` off and `height` above his middle.
func _filmstrip(move: String, gap := 2, count := 8, distance := 4.2, height := 0.4) -> void:
	var sheet := Image.create(SIZE.x * 4, SIZE.y * ceili(count / 4.0), false, Image.FORMAT_RGBA8)
	# (the first picture is taken once the view has drawn with the camera where it is put)
	var first := true
	for k in count:
		var at := player.visual_position + Vector3.UP * 0.4
		var a := player.facing_yaw + PI * 0.5
		eye.global_position = at + Vector3(sin(a) * distance, height, cos(a) * distance)
		eye.look_at(at, Vector3.UP)
		await process_frame
		await process_frame
		if first:
			first = false
			for _f in 3:
				await process_frame
		var image := view.get_texture().get_image()
		image.convert(Image.FORMAT_RGBA8)
		sheet.blit_rect(image, Rect2i(Vector2i.ZERO, SIZE), Vector2i(SIZE.x * (k % 4), SIZE.y * (k / 4)))
		await _frames(gap)
	sheet.save_png(out.path_join(move + ".png"))
	print("SHOT ", move)


## Running, put back across the field from the way he is going, so he has the length of it ahead of him.
func _recentre() -> void:
	var flat := Vector3(player.velocity.x, 0.0, player.velocity.z)
	if flat.length() < 0.1:
		return
	var back := -flat.normalized() * 22.0
	player.global_position = Vector3(back.x, 0.05, back.z)
	player.reset_physics_interpolation()


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
