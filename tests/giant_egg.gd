extends SceneTree
## The giant's shape (Villagers.GIANT, EGG; the user, 2026-11-02: "he needs to have more of an egg silhouette too"):
## alone on open ground in the playground, him beside it for scale, sitting and snoozing from four sides and above,
## then standing from the front and side. A window (kept off the screen):
##   godot --path . --audio-driver Dummy --fixed-fps 60 --resolution 1024x1024 -s res://tests/giant_egg.gd -- --out=<dir>

var out := "user://giant_egg"
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


func _shot(eye: Camera3D, from: Vector3, at: Vector3, called: String) -> void:
	eye.look_at_from_position(from, at)
	for _i in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [out, called])


func _run(level: Node3D) -> void:
	for _i in 10:
		await physics_frame
	var player: Player = level.player
	player.global_position = OFF + Vector3(1.6, 0.1, 1.2)
	var band := Villagers.new()
	band.player = player
	level.add_child(band)
	band.talk = Chatter.new()
	band.talk.villagers = band
	band.add_child(band.talk)
	var giant := band._add(false, 8, OFF + Vector3.UP * 0.3, Villagers.GIANT)
	giant.home = OFF
	var eye := Camera3D.new()
	eye.fov = 40.0
	level.add_child(eye)
	eye.make_current()
	var middle := OFF + Vector3.UP * 1.0
	for pose: String in ["sit", "stand"]:
		giant._go(Villager.Doing.SIT if pose == "sit" else Villager.Doing.STAND, 60.0)
		for _i in 150:
			giant.rotation.y = 0.0
			await physics_frame
		var sides := ["front", "left", "back", "right"] if pose == "sit" else ["front", "left"]
		for k in sides.size():
			var way := Vector3.BACK.rotated(Vector3.UP, k * PI / 2.0)
			await _shot(eye, middle + way * 7.5 + Vector3.UP * 0.3, middle, "%s_%s" % [pose, sides[k]])
		if pose == "sit":
			await _shot(eye, middle + Vector3(0.0, 7.0, 1.0), middle, "sit_above")
	print("GIANT EGG DONE ", out)
	quit()
