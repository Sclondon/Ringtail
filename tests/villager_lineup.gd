extends SceneTree
## A lineup of the town's raccoons, each its own build (Villagers._random_build), the characters among them, from the
## front and the side. A window (kept off the screen):
##   godot --path . --audio-driver Dummy --fixed-fps 60 --resolution 1600x600 -s res://tests/villager_lineup.gd -- --out=<dir>

var out := "user://villager_lineup"
## Where they stand: open ground in the playground.
const OFF := Vector3(10.0, 0.0, -14.0)


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.substr(6)
	DirAccess.make_dir_recursive_absolute(out)
	root.position = Vector2i(-3000, 0)
	var level: Node3D = load("res://scenes/playground.tscn").instantiate()
	root.add_child(level)
	_run.call_deferred(level)


func _run(level: Node3D) -> void:
	for _i in 10:
		await physics_frame
	var player: Player = level.player
	# (near enough that their rigs are awake: past 45 m they sleep, hidden)
	player.global_position = OFF + Vector3(0.0, 0.1, 9.0)
	var band := Villagers.new()
	band.player = player
	level.add_child(band)
	band.talk = Chatter.new()
	band.talk.villagers = band
	band.add_child(band.talk)
	var specials: Array = [Villagers.OLD_GREY, Villagers.LANKY, {}, {}, {}, {}, {}, {}, {}]
	var x := -5.0
	for k in 9:
		var adult := band._add(false, k, OFF + Vector3(x, 0.3, 0.0), specials[k])
		adult.home = OFF + Vector3(x, 0.0, 0.0)
		x += 1.0 + 0.3 * float(adult.build.girth)
	for k in 4:
		var kit := band._add(true, k + 2, OFF + Vector3(x, 0.3, 0.0), Villagers.RUNT if k == 0 else {})
		kit.home = OFF + Vector3(x, 0.0, 0.0)
		x += 0.7
	for _i in 40:
		await physics_frame
	for member in band.members:
		member.process_mode = Node.PROCESS_MODE_DISABLED
		member.rotation.y = 0.0
		member.rig.process_mode = Node.PROCESS_MODE_ALWAYS
	var middle := OFF + Vector3((x - 5.0) * 0.5 - 0.5, 0.45, 0.0)
	var eye := Camera3D.new()
	eye.fov = 32.0
	level.add_child(eye)
	for view: Array in [["front", Vector3(0.0, 0.4, 14.0)], ["side", Vector3(-15.0, 1.2, 6.0)]]:
		eye.look_at_from_position(middle + view[1], middle)
		eye.make_current()
		for _i in 6:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("%s/%s.png" % [out, view[0]])
	print("LINEUP DONE ", out)
	quit()
