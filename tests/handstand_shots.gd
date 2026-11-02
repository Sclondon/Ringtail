extends SceneTree
## The one-hand handstand on a pole's top (PointStand) photographed from the front, his left, behind, his right and
## above, close in, in one strip. A window (kept off the screen):
##   godot --path . --audio-driver Dummy --fixed-fps 60 --resolution 1280x720 -s res://tests/handstand_shots.gd -- --out=<dir>

const SIZE := Vector2i(360, 420)

var out := "user://handstand_shots"


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.substr(6)
	DirAccess.make_dir_recursive_absolute(out)
	root.position = Vector2i(-3000, 0)
	var world: World = (load("res://scenes/world1.tscn") as PackedScene).instantiate()
	root.add_child(world)
	_run.call_deferred(world)


func _run(world: World) -> void:
	for _i in 30:
		await physics_frame
	var pole := PointPerches.points[0]
	for p in PointPerches.points:
		if absf(p.y - 8.2) < 0.05:
			pole = p
			break
	world.player.global_position = pole + Vector3(0.1, 0.8, 0.0)
	world.player.velocity = Vector3.ZERO
	world.player.facing_yaw = 0.0
	for _i in 90:
		await physics_frame
	var view := SubViewport.new()
	view.size = SIZE
	view.world_3d = root.world_3d
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	var eye := Camera3D.new()
	eye.fov = 40.0
	view.add_child(eye)
	var middle := pole + Vector3.UP * 0.45
	var sheet := Image.create(SIZE.x * 5, SIZE.y, false, Image.FORMAT_RGBA8)
	var spots := [Vector3(0, 0.2, 2.2), Vector3(2.2, 0.2, 0), Vector3(0, 0.2, -2.2), Vector3(-2.2, 0.2, 0), Vector3(0.01, 2.4, 0.3)]
	for k in spots.size():
		eye.look_at_from_position(middle + spots[k], middle)
		for _i in 3:
			await process_frame
		await RenderingServer.frame_post_draw
		var shot := view.get_texture().get_image()
		shot.convert(Image.FORMAT_RGBA8)
		sheet.blit_rect(shot, Rect2i(Vector2i.ZERO, SIZE), Vector2i(SIZE.x * k, 0))
	sheet.save_png(out + "/handstand.png")
	print("HANDSTAND SHOTS DONE ", out)
	quit()
