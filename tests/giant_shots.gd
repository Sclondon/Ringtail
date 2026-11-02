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
	# Close up, sitting, from four sides (the user, 2026-11-02: "he needs to have more of an egg silhouette too"), and above
	giant._go(Villager.Doing.SIT, 60.0)
	for _i in 120:
		await physics_frame
	var facing := Vector3(sin(giant.rotation.y), 0.0, cos(giant.rotation.y))
	for side in 4:
		var way := facing.rotated(Vector3.UP, side * PI / 2.0)
		eye.look_at_from_position(giant.global_position + way * 5.0 + Vector3.UP * 1.3, giant.global_position + Vector3.UP * 1.0)
		await _shot("sit_%s" % ["front", "left", "back", "right"][side])
	eye.look_at_from_position(giant.global_position + facing * 1.5 + Vector3.UP * 6.0, giant.global_position + Vector3.UP * 0.8)
	await _shot("sit_above")
	# He beside it, for scale, from the front
	player.global_position = giant.global_position + facing * 1.6 + facing.cross(Vector3.UP) * 1.2 + Vector3.UP * 0.3
	for _i in 30:
		await physics_frame
	eye.look_at_from_position(giant.global_position + facing * 6.5 + Vector3.UP * 1.4, giant.global_position + Vector3.UP * 0.9)
	await _shot("beside_him")
	# He comes down on top of it and stands there
	player.global_position = giant.global_position + facing * 0.3 + Vector3.UP * 2.5
	player.velocity = Vector3.ZERO
	for _i in 90:
		await physics_frame
	print("GIANT oak %s heart %s giant %s" % [world.markers.get("great_oak", Transform3D()).origin, world.markers.get("grove_heart", Transform3D()).origin, giant.global_position])
	var up_on := player.is_on_floor() and player.global_position.y - giant.global_position.y > 0.8
	print("GIANT size %.1f drum %.2f height of him on it %.2f on floor %s -> %s" % [giant.rig.scale.x, giant._solid_shape.height, player.global_position.y - giant.global_position.y, player.is_on_floor(), "STANDS ON IT" if up_on else "NOT ON IT"])
	world.camera.make_current()
	await _shot("on_top")
	print("GIANT SHOTS DONE ", out)
	quit()
