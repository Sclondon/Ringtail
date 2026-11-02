extends SceneTree
## Pictures of playing as the animals (AnimalPlayer): the pause screen's Animals page, then a few of them in the grove
## behind their camera, standing and running, and each one's tail-button thing. Needs a window:
##   godot --path . --audio-driver Dummy --fixed-fps 60 --resolution 1280x720 -s res://tests/play_as_shots.gd -- --out=<dir> [fox ...]
## (and at --resolution 390x844 for a phone; only the page is shot then)

const SOME := ["fox", "cat_1", "beagle", "frog", "porcupine", "skunk", "opossum", "snake", "mouse", "dachshund"]

var out := ""
var tag := ""


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.substr(6)
	DirAccess.make_dir_recursive_absolute(out)
	var world: World = (load("res://scenes/world1.tscn") as PackedScene).instantiate()
	root.add_child(world)
	_run.call_deferred(world)


func _frames(count: int) -> void:
	for _i in count:
		await process_frame


func _shoot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join("%s_%s.png" % [name, tag]))
	print("SHOT ", name)


func _run(world: World) -> void:
	var size := root.get_visible_rect().size
	tag = "%dx%d" % [size.x, size.y]
	await _frames(40)
	world.hud.pause.open()
	world.hud.pause._card.visible = false
	world.hud.pause._zoo.visible = true
	await _frames(5)
	await _shoot("animals_page")
	world.hud.pause.close()
	if size.aspect() < 1.0:
		quit()
		return
	var only: Array = []
	for arg in OS.get_cmdline_user_args():
		if not arg.begins_with("--"):
			only.append(arg)
	for what: String in SOME:
		if not only.is_empty() and not what in only:
			continue
		BirdPlayer.play_as(world, StringName(what))
		await _frames(10)
		var animal := BirdPlayer.active(world) as AnimalPlayer
		animal.global_position = world.player.global_position + Vector3.UP * 0.2
		await _frames(40)
		await _shoot("%s_stand" % what)
		Input.action_press(&"move_up", 1.0)
		await _frames(45)
		await _shoot("%s_run" % what)
		Input.action_release(&"move_up")
		await _frames(30)
		animal.press(&"tail", true)
		await _frames(25)
		await _shoot("%s_tail" % what)
		animal.press(&"tail", false)
		await _frames(5)
	BirdPlayer.play_as(world, &"raccoon")
	await _frames(5)
	quit()
