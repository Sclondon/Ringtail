extends SceneTree
## Scurry held near the grove's trees: the blue sparkles on what can be climbed. A window (kept off the screen):
##   godot --path . --audio-driver Dummy --fixed-fps 60 --resolution 1280x720 -s res://tests/climb_glint_shots.gd -- --out=<dir>

var out := "user://climb_glint_shots"


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
	for _i in 60:
		await physics_frame
	(world.player.get_node(^"Scurry") as Scurry).button = true
	for k in 3:
		for _i in 12:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("%s/glints_%d.png" % [out, k])
	print("CLIMB GLINT SHOTS DONE ", out)
	quit()
