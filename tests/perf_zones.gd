extends SceneTree
## How heavy each zone is: he is set down in the grove and in the middle of each side of the hill in turn, and for
## two seconds it measures the frame (ms), the process and physics time, draw calls, primitives, nodes and active
## physics bodies. Needs a window (draw calls are counted only when drawing; kept off the screen):
##   godot --path . --audio-driver Dummy --resolution 1280x720 -s res://tests/perf_zones.gd [-- --no-stream]

var world: World


func _initialize() -> void:
	root.position = Vector2i(-3000, 0)
	ZoneStreaming.enabled = not "--no-stream" in OS.get_cmdline_user_args()
	world = (load("res://scenes/world1.tscn") as PackedScene).instantiate()
	root.add_child(world)
	_run.call_deferred()


## (the pause screen opens when the window loses focus, as it does kept off the screen: shut it, or nothing runs)
func _process(_delta: float) -> bool:
	if world and world.hud and world.hud.pause and world.hud.pause.is_open():
		world.hud.pause.close()
	return false


func _ground(at: Vector3) -> Vector3:
	var hit := world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(at + Vector3.UP * 60.0, at + Vector3.DOWN * 80.0, 1))
	return (hit.position as Vector3) if not hit.is_empty() else at


func _run() -> void:
	for _i in 90:
		await process_frame
	var spots := [["Grove", world.player.global_position]]
	for name: String in world.markers:
		if name.begins_with("zone_"):
			spots.append([name.get_slice("_", 2), _ground((world.markers[name] as Transform3D).origin)])
	for spot: Array in spots:
		world.player.global_position = (spot[1] as Vector3) + Vector3.UP * 0.5
		world.player.velocity = Vector3.ZERO
		world.camera.snap()
		# (settled: what streams in, in; the grass filled)
		for _i in 120:
			await process_frame
		var frame := 0.0
		var worst := 0.0
		var process := 0.0
		var physics := 0.0
		var draws := 0.0
		var prims := 0.0
		var n := 120
		var last := Time.get_ticks_usec()
		for _i in n:
			await process_frame
			var now := Time.get_ticks_usec()
			var ms := (now - last) / 1000.0
			last = now
			frame += ms
			worst = maxf(worst, ms)
			process += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
			physics += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
			draws += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
			prims += Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
		print("PERF %-8s frame %5.1f ms (worst %5.1f)  process %5.2f ms  physics %5.2f ms  draws %5d  prims %7dk  nodes %d  bodies %d" % [
			spot[0], frame / n, worst, process / n, physics / n, int(draws / n), int(prims / n / 1000.0),
			int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)), int(Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS))])
	quit()
