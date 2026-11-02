extends SceneTree
## A car on the hill, rounding its road's sharpest hairpin, seen from the side a few times as it goes (its wheels on
## the road, the body pitched and leaning, the front wheels steering): a window (kept off the screen):
##   godot --path . --audio-driver Dummy --fixed-fps 60 --resolution 1280x720 -s res://tests/vehicle_hill_shots.gd -- --out=<dir> [night]

var out := "user://vehicle_hill_shots"
var night := false


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.substr(6)
		elif arg == "night":
			night = true
	DirAccess.make_dir_recursive_absolute(out)
	root.position = Vector2i(-3000, 0)
	var world: World = (load("res://scenes/world1.tscn") as PackedScene).instantiate()
	root.add_child(world)
	_run.call_deferred(world)


func _run(world: World) -> void:
	for _i in 20:
		await physics_frame
	for node in world.find_children("*", "ZoneStreaming", true, false):
		node.queue_free()
	if DayNight.current:
		DayNight.current.set_hour(23.0 if night else 12.0)
		DayNight.current.held = true
	await physics_frame
	var car: HazardCar
	for node in get_nodes_in_group(&"cars"):
		(node as Node).process_mode = Node.PROCESS_MODE_INHERIT
		(node as Node3D).visible = true
		if car == null and (node as HazardCar).road >= 1 and (node as HazardCar).kind != &"bus":
			car = node
	# Its road's sharpest bend
	var sharpest := 0.0
	var at := 0.0
	var s := 0.0
	while s < car.loop_length():
		# (sharp, and on the slope: how much it turns times how much it falls)
		var bend := (car.point_at(s)[1] as Vector3).angle_to(car.point_at(s + 8.0)[1])
		bend *= absf((car.point_at(s + 12.0)[0] as Vector3).y - (car.point_at(s - 12.0)[0] as Vector3).y)
		if bend > sharpest:
			sharpest = bend
			at = s
		s += 2.0
	car.along = fposmod(at - 14.0, car.loop_length())
	car.speed = car.cruise * 0.6
	car._stop_left = 0.0
	car._stop_wait = 99.0
	var corner: Vector3 = car.point_at(at + 4.0)[0]
	var eye := Camera3D.new()
	eye.fov = 45.0
	eye.far = 400.0
	world.add_child(eye)
	eye.make_current()
	world.player.global_position = corner + Vector3(0.0, 30.0, 0.0)
	world.player.process_mode = Node.PROCESS_MODE_DISABLED
	for frame in 6:
		for _i in 18:
			await physics_frame
			# (from beside the car, the outside of the bend, a little above)
			var side := car.global_basis.x
			eye.look_at_from_position(car.global_position + side * 8.0 + Vector3.UP * 2.5, car.global_position + Vector3.UP * 0.6)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("%s/hairpin_%d.png" % [out, frame])
		print("frame %d: %s on road %d, %.1f m/s, pitch %.1f deg, roll %.1f deg, steer %.2f, wheels off the road %.3f m" % [
			frame, car.kind, car.road, car.speed, rad_to_deg(car._pitch), rad_to_deg(car._roll),
			car._wheels[0].rotation.y if not car._wheels.is_empty() else 0.0, car.contact_error])
	print("VEHICLE HILL SHOTS DONE ", out)
	quit()
