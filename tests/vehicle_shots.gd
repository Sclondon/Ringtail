extends SceneTree
## Each vehicle (HazardCar's kinds) standing beside the raccoon, from four sides, in the game's shading:
##   godot --path . --audio-driver Dummy --fixed-fps 60 --resolution 1280x720 -s res://tests/vehicle_shots.gd -- --out=<dir>
## Needs a window (kept off the screen).

var out := "user://vehicle_shots"


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
	var eye := Camera3D.new()
	eye.fov = 40.0
	level.add_child(eye)
	eye.make_current()
	var x := 0.0
	var placed: Array[HazardCar] = []
	for kind: StringName in HazardCar.KINDS:
		var car := HazardCar.new()
		car.kind = kind
		car.route = PackedVector3Array([Vector3(x, 0.05, -20.0), Vector3(x, 0.05, -40.0)])
		car.paint = Hazards.KIND_PAINTS[kind][0] if Hazards.KIND_PAINTS.has(kind) else Color(0.85, 0.22, 0.18)
		if Hazards.KIND_PAINTS.has(kind):
			car.paint2 = Hazards.KIND_PAINTS[kind][1]
		level.add_child(car)
		car.process_mode = Node.PROCESS_MODE_DISABLED
		placed.append(car)
		x += 4.5
	for car in placed:
		# (one at a time: the others out of sight)
		for other in placed:
			other.visible = other == car
		player.global_position = car.global_position + Vector3(car.half_size.x + 0.7, 0.3, car.half_size.z - 0.5)
		player.velocity = Vector3.ZERO
		for _i in 40:
			await physics_frame
		var middle := car.global_position + Vector3(0.0, car.half_size.y, 0.0)
		var reach := car.half_size.z * 2.0 + 4.0
		for view: Array in [["side", Vector3(1.0, 0.25, 0.0)], ["front", Vector3(0.0, 0.25, -1.0)], ["back", Vector3(0.0, 0.25, 1.0)], ["quarter", Vector3(0.8, 0.45, -0.8)]]:
			eye.look_at_from_position(middle + (view[1] as Vector3).normalized() * reach, middle)
			for _i in 3:
				await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("%s/%s_%s.png" % [out, car.kind, view[0]])
	print("VEHICLE SHOTS DONE ", out)
	quit()
