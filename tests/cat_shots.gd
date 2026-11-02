extends SceneTree
## Photographs a yard cat wandering, stalking, crouched to pounce, mid-pounce and knocked tumbling, each from its
## front, its left, behind and a quarter (one strip a moment):
##   godot --path . --audio-driver Dummy --fixed-fps 60 --resolution 960x540 -s res://tests/cat_shots.gd -- --out=<dir>
## Needs a window (kept off the screen).

const SIZE := Vector2i(360, 400)

var out := "user://cat_shots"
var view: SubViewport
var eye: Camera3D
var cat: YardCat
var player: Player


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.substr(6)
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


func _frames(count: int) -> void:
	for _i in count:
		await physics_frame


func _run(level: Node3D) -> void:
	await process_frame
	player = level.player
	player.global_position = Vector3(12.0, 0.05, -7.0)
	cat = YardCat.make()
	cat.position = Vector3(12.0, 0.05, -2.0)
	level.add_child(cat)
	await _frames(90)
	await _strip("wander")
	cat.target = player
	await _wait_for(YardCat.Mode.STALK, 30)
	await _frames(25)
	await _strip("stalk")
	await _wait_for(YardCat.Mode.CROUCH, 400)
	await _frames(30)
	await _strip("crouch")
	await _wait_for(YardCat.Mode.POUNCE, 120)
	await _frames(8)
	await _strip("pounce", true)
	await _frames(60)
	cat.tail_hit(cat.global_position + Vector3.FORWARD, Vector3(0.0, 2.5, 6.0))
	await _frames(10)
	await _strip("dazed", true)
	print("CAT SHOTS DONE ", out)
	quit()


func _wait_for(what: YardCat.Mode, most: int) -> void:
	for _i in most:
		if cat.mode == what:
			return
		await physics_frame
	print("never got to mode ", what, " (it is ", cat.mode, ")")


func _strip(name: String, moving := false) -> void:
	var sheet := Image.create(SIZE.x * 4, SIZE.y, false, Image.FORMAT_RGBA8)
	var angles := [0.0, PI * 0.5, PI, PI * 0.25]
	for k in angles.size():
		var at := cat.global_position + Vector3.UP * 0.35
		var a: float = cat.rotation.y + angles[k]
		eye.global_position = at + Vector3(sin(a) * 2.2, 0.5, cos(a) * 2.2)
		eye.look_at(at, Vector3.UP)
		# (a moving cat is taken in the frame it is framed in; a still one after the picture has settled)
		await process_frame
		if not moving:
			await process_frame
		await process_frame
		var image := view.get_texture().get_image()
		image.convert(Image.FORMAT_RGBA8)
		sheet.blit_rect(image, Rect2i(Vector2i.ZERO, SIZE), Vector2i(SIZE.x * k, 0))
	sheet.save_png(out.path_join(name + ".png"))
	print("SHOT ", name, " mode ", cat.mode)
