extends SceneTree
## Pictures of the raccoon squad about him: standing (they settle and sit), then following him at a run, from a few
## angles each:
##   godot --path . --audio-driver Dummy --fixed-fps 60 --resolution 960x540 -s res://tests/squad_shots.gd -- --out=<dir>
## Needs a window (kept off the screen).

const SIZE := Vector2i(480, 400)
var out := "user://squad_shots"
var player: Player
var view: SubViewport
var eye: Camera3D


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.substr(6)
	DirAccess.make_dir_recursive_absolute(out)
	root.position = Vector2i(-3000, 0)
	var level: Node3D = (load("res://scenes/playground.tscn") as PackedScene).instantiate()
	root.add_child(level)
	view = SubViewport.new()
	view.size = SIZE
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	eye = Camera3D.new()
	eye.fov = 45.0
	view.add_child(eye)
	_run.call_deferred(level)


func _frames(count: int) -> void:
	for _i in count:
		await physics_frame


func _run(level: Node3D) -> void:
	await process_frame
	player = level.player
	player.global_position = Vector3(12.0, 0.05, -12.0)
	await _frames(10)
	Squad.place(level, player)
	await _frames(300)
	await _strip("standing", [0.3, 2.0, 4.0])
	Input.action_press(&"move_up")
	await _frames(70)
	await _strip("running", [PI * 0.5, PI, -0.6])
	Input.action_release(&"move_up")
	print("SQUAD SHOTS DONE ", out)
	quit()


func _strip(name: String, angles: Array) -> void:
	var sheet := Image.create(SIZE.x * angles.size(), SIZE.y, false, Image.FORMAT_RGBA8)
	for k in angles.size():
		var at := player.visual_position + Vector3.UP * 0.3
		var a: float = player.facing_yaw + angles[k]
		eye.global_position = at + Vector3(sin(a) * 4.0, 1.6, cos(a) * 4.0)
		eye.look_at(at, Vector3.UP)
		for _f in 3:
			await process_frame
		var image := view.get_texture().get_image()
		image.convert(Image.FORMAT_RGBA8)
		sheet.blit_rect(image, Rect2i(Vector2i.ZERO, SIZE), Vector2i(SIZE.x * k, 0))
	sheet.save_png(out.path_join(name + ".png"))
	print("SHOT ", name)
