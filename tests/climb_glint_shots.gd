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
	# (about 9 m off the nearest climbable thing, facing it)
	var near: Node3D
	for node in get_nodes_in_group(&"climbable"):
		# (a tree has its own place; a mesh of many poles sits at the middle of the world)
		if node is Node3D and (node as Node3D).global_position.length() > 2.0 and (near == null or (node as Node3D).global_position.distance_to(world.player.global_position) < near.global_position.distance_to(world.player.global_position)):
			near = node
	if near:
		var away := world.player.global_position - near.global_position
		away.y = 0.0
		world.player.global_position = near.global_position + away.normalized() * 9.0 + Vector3.UP * 0.5
		world.player.facing_yaw = atan2(-away.x, -away.z)
		world.camera.snap()
		for _i in 30:
			await physics_frame
	(world.player.get_node(^"Scurry") as Scurry).button = true
	for k in 3:
		for _i in 12:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("%s/glints_%d.png" % [out, k])
	print("CLIMB GLINT SHOTS DONE ", out)
	quit()
