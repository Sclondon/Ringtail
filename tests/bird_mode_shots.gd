extends SceneTree
## Pictures of playing as a bird (BirdPlayer): the crow and the owl flying, from their own camera, and the pause screen
## with its "Play as" row. A window (kept off the screen):
##   godot --path . --audio-driver Dummy --fixed-fps 60 --resolution 1280x720 -s res://tests/bird_mode_shots.gd -- --out=<dir>

var out := "user://bird_mode_shots"
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
		await physics_frame


func _shot(called: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [out, called])


func _run() -> void:
	await _frames(30)
	for kind: StringName in [&"crow", &"owl"]:
		BirdPlayer.play_as(world, kind)
		await _frames(5)
		var bird := BirdPlayer.active(world)
		# (up off the grove, then on ahead, flapping now and then)
		Input.action_press(&"move_up")
		for k in 14:
			bird.press(&"jump", true)
			await _frames(2)
			bird.press(&"jump", false)
			await _frames(10)
		await _shot("%s_flying" % kind)
		Input.action_press(&"move_right", 0.7)
		await _frames(30)
		await _shot("%s_turning" % kind)
		Input.action_release(&"move_right")
		bird.press(&"jump", true)
		await _frames(60)
		await _shot("%s_gliding" % kind)
		bird.press(&"jump", false)
		Input.action_release(&"move_up")
	world.hud.pause.open()
	await _frames(10)
	await _shot("pause")
	world.hud.pause.close()
	print("BIRD MODE SHOTS DONE ", out)
	quit()
