extends SceneTree
## Pictures of World 1 as played: the start, a few places in it, the filter off,
## and a race under way.
##   godot --path . --audio-driver Dummy --fixed-fps 60 --resolution 1280x720 -s res://tests/shots.gd -- --out=<dir>
## Needs a window (kept off the screen). Try --resolution 390x844 for a phone.

var out := "user://shots"
var world: World


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.substr(6)
	DirAccess.make_dir_recursive_absolute(out)
	root.position = Vector2i(-3000, 0)
	world = (load("res://scenes/world1.tscn") as PackedScene).instantiate()
	root.add_child(world)
	_run.call_deferred()


func _frames(count: int) -> void:
	for _i in count:
		await process_frame


func _shot(name: String) -> void:
	await _frames(3)
	root.get_texture().get_image().save_png(out.path_join(name + ".png"))
	print("SHOT ", name)


func _put(at: Vector3, yaw: float) -> void:
	world.player.global_position = at
	world.player.velocity = Vector3.ZERO
	world.player.facing_yaw = yaw
	world.camera.snap()
	await _frames(40)


func _run() -> void:
	await _frames(60)
	await _shot("start")
	await _put(Vector3(0.0, 3.6, 16.0), PI)
	await _shot("hill")
	await _put(Vector3(0.0, 7.2, 6.0), PI)
	await _shot("grove")
	await _put(Vector3(21.0, 0.15, 21.0), PI * 0.75)
	await _shot("street")
	for node in world.get_children():
		if node is N64Filter:
			node.visible = false
	await _shot("street_plain")
	for node in world.get_children():
		if node is N64Filter:
			node.visible = true
	world.race.start()
	await _put(Vector3(-2.0, 0.15, 34.0), PI)
	await _shot("race")
	print("SHOTS DONE ", out)
	quit()
