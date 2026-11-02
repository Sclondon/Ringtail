extends SceneTree
## Pictures of the UI (UiStyle, Icon): the HUD by day and by night, a count bouncing, the testing panel opened, every
## symbol large, by the pond's fishing button, as the crow, the pause screen and the fur editor. Needs a window (kept
## off the screen):
##   godot --path . --audio-driver Dummy --fixed-fps 60 --resolution 1280x720 -s res://tests/ui_shots.gd -- --out=<dir>
## (and at --resolution 390x844 for a phone)

var out := "user://ui_shots"
var tag := ""


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.substr(6)
	DirAccess.make_dir_recursive_absolute(out)
	root.position = Vector2i(-3000, 0)
	_run.call_deferred()


func _frames(count: int) -> void:
	for _i in count:
		await process_frame


func _shoot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join("%s_%s.png" % [name, tag]))
	print("SHOT ", name)


func _run() -> void:
	var size := root.get_visible_rect().size
	tag = "%dx%d" % [size.x, size.y]
	# Every symbol, big, on the button colour
	var sheet := ColorRect.new()
	sheet.color = UiStyle.FIR
	sheet.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(sheet)
	var grid := GridContainer.new()
	grid.columns = 8 if size.x > size.y else 4
	grid.position = Vector2(20, 20)
	sheet.add_child(grid)
	for kind in Icon.Kind.values():
		grid.add_child(Icon.make(kind, 120.0 if size.x > size.y else 84.0, Color(0.98, 0.78, 0.25) if kind == Icon.Kind.CAP else UiStyle.CREAM))
	await _frames(3)
	await _shoot("icons")
	sheet.queue_free()

	var world: World = (load("res://scenes/world1.tscn") as PackedScene).instantiate()
	root.add_child(world)
	await _frames(40)
	if DayNight.current:
		DayNight.current.set_hour(12.0)
	await _frames(10)
	await _shoot("hud_day")
	# A count changing: its badge mid-bounce
	world.hud._crumbs.text = "99 / 99"
	await _frames(4)
	await _shoot("hud_bounce")
	if world.hud._dev:
		world.hud._dev.visible = true
		await _frames(3)
		await _shoot("hud_dev")
		world.hud._dev.visible = false
	if DayNight.current:
		DayNight.current.set_hour(0.5)
	await _frames(10)
	await _shoot("hud_night")
	if DayNight.current:
		DayNight.current.set_hour(12.0)
	# By the pond: the fishing button
	var fishing := world.get_node_or_null(^"PondFishing") as PondFishing
	if fishing and fishing.spot:
		world.player.global_position = fishing.spot.global_position + Vector3.UP * 0.3
		world.player.velocity = Vector3.ZERO
		await _frames(30)
		await _shoot("hud_fishing")
	# As the crow
	BirdPlayer.play_as(world, &"crow")
	await _frames(30)
	await _shoot("hud_crow")
	BirdPlayer.play_as(world, &"raccoon")
	await _frames(10)
	world.hud.pause.open()
	await _frames(5)
	await _shoot("pause")
	world.hud.pause._edit()
	await _frames(40)
	await _shoot("editor")
	root.get_tree().paused = false
	quit()
