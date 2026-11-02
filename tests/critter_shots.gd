extends SceneTree
## Photographs the fox, skunk, badger and rabbit (CritterRig on a stand-in Critter body) standing, walking and
## running, each from its front, its left, behind and a quarter: one picture an animal, a row a gait.
##   godot --path . --audio-driver Dummy --fixed-fps 60 --resolution 960x540 -s res://tests/critter_shots.gd -- --out=<dir> [kinds...]
## Needs a window (kept off the screen).

const SIZE := Vector2i(320, 320)
const GAITS := [["stand", 0.0], ["walk", 0.9], ["run", 3.8]]

var out := "user://critter_shots"
var only: Array[String] = []
var view: SubViewport
var eye: Camera3D
var level: Node3D


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.substr(6)
		else:
			only.append(arg)
	DirAccess.make_dir_recursive_absolute(out)
	root.position = Vector2i(-3000, 0)
	level = load("res://scenes/playground.tscn").instantiate()
	root.add_child(level)
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
		await physics_frame


func _run() -> void:
	await process_frame
	for kind: String in CritterRig.KINDS:
		if only.is_empty() or kind in only:
			await _animal(kind)
	print("CRITTER SHOTS DONE ", out)
	quit()


func _animal(kind: String) -> void:
	var body := Critter.make(kind)
	body.position = Vector3(14.0, 0.05, -14.0)
	level.add_child(body)
	var sheet := Image.create(SIZE.x * 4, SIZE.y * GAITS.size(), false, Image.FORMAT_RGBA8)
	for row in GAITS.size():
		body.global_position = Vector3(14.0, 0.05, -14.0)
		body.drive = Vector3(0.0, 0.0, 1.0) * float(GAITS[row][1])
		await _frames(70)
		var angles := [0.0, PI * 0.5, PI, PI * 0.25]
		for k in angles.size():
			var at := body.global_position + Vector3.UP * 0.35
			var a: float = body.rotation.y + angles[k]
			eye.global_position = at + Vector3(sin(a) * 2.3, 0.45, cos(a) * 2.3)
			eye.look_at(at, Vector3.UP)
			for _f in 4:
				await process_frame
			var image := view.get_texture().get_image()
			image.convert(Image.FORMAT_RGBA8)
			sheet.blit_rect(image, Rect2i(Vector2i.ZERO, SIZE), Vector2i(SIZE.x * k, SIZE.y * row))
	sheet.save_png(out.path_join(kind + ".png"))
	print("SHOT ", kind)
	body.queue_free()
	await process_frame
