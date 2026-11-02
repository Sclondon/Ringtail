extends SceneTree
## The giant of the grove (Villagers.GIANT): seen from where he starts, and close up; and he lands on it and stands
## up there. A window (kept off the screen):
##   godot --path . --audio-driver Dummy --fixed-fps 60 --resolution 1280x720 -s res://tests/giant_shots.gd -- --out=<dir>

var out := "user://giant_shots"


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.substr(6)
	DirAccess.make_dir_recursive_absolute(out)
	root.position = Vector2i(-3000, 0)
	var world: World = (load("res://scenes/world1.tscn") as PackedScene).instantiate()
	root.add_child(world)
	_run.call_deferred(world)


func _shot(called: String) -> void:
	for _i in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [out, called])


func _run(world: World) -> void:
	for _i in 60:
		await physics_frame
	var band := world.get_node(^"Villagers") as Villagers
	var giant: Villager
	for member in band.members:
		if member.giant:
			giant = member
	if giant == null:
		print("GIANT MISSING")
		quit()
		return
	var player := world.player
	var spawn := player.global_position
	# From where he starts, looking to it
	var eye := Camera3D.new()
	eye.fov = 55.0
	world.add_child(eye)
	eye.look_at_from_position(spawn + Vector3.UP * 1.4, giant.global_position + Vector3.UP * 1.5)
	eye.make_current()
	await _shot("from_spawn")
	# Close up, from the front and the side
	var facing := Vector3(sin(giant.rotation.y), 0.0, cos(giant.rotation.y))
	eye.look_at_from_position(giant.global_position + facing * 6.0 + Vector3.UP * 1.8, giant.global_position + Vector3.UP * 1.6)
	await _shot("close_front")
	eye.look_at_from_position(giant.global_position + facing.cross(Vector3.UP) * 6.5 + Vector3.UP * 1.8, giant.global_position + Vector3.UP * 1.6)
	await _shot("close_side")
	# He comes down on top of it and stands there
	player.global_position = giant.global_position + Vector3.UP * 4.5
	player.velocity = Vector3.ZERO
	for _i in 90:
		await physics_frame
	var up_on := player.is_on_floor() and player.global_position.y - giant.global_position.y > 2.0
	print("GIANT size %.1f height of him on it %.2f on floor %s -> %s" % [giant.rig.scale.x, player.global_position.y - giant.global_position.y, player.is_on_floor(), "STANDS ON IT" if up_on else "NOT ON IT"])
	world.camera.make_current()
	await _shot("on_top")
	print("GIANT SHOTS DONE ", out)
	quit()
