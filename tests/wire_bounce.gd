extends SceneTree
## Bouncing on a wire: stood still on it he should not jitter; jumps timed to its rebound should go higher and
## higher. Prints each jump's height, PASSED or FAILED. Headless:
##   godot --headless --path . --audio-driver Dummy --fixed-fps 60 -s res://tests/wire_bounce.gd

var world: World


func _initialize() -> void:
	world = (load("res://scenes/world1.tscn") as PackedScene).instantiate()
	root.add_child(world)
	_run.call_deferred()


func _frames(count: int) -> void:
	for _i in count:
		await physics_frame


func _run() -> void:
	await _frames(10)
	var player := world.player
	var wire: Tightrope
	for node in get_nodes_in_group(&"tightropes"):
		var w := node as Tightrope
		if w.span() > 6.0:
			wire = w
			break
	if wire == null:
		print("FAILED: no wire")
		quit()
		return
	var middle := wire.point_at_distance(wire.span() * 0.5)
	player.global_position = middle + Vector3.UP * 0.6
	player.velocity = Vector3.ZERO
	wire.bodies_now()
	# Stood still (once the drop onto it has died away): how much he shakes
	await _frames(240)
	var lowest := INF
	var highest := -INF
	var floor_flips := 0
	var was := player.is_on_floor()
	for _i in 120:
		await physics_frame
		lowest = minf(lowest, player.global_position.y)
		highest = maxf(highest, player.global_position.y)
		if player.is_on_floor() != was:
			floor_flips += 1
		was = player.is_on_floor()
	var shake := highest - lowest
	print("standing: moves %.3f m, floor flips %d, on it %s" % [shake, floor_flips, wire.carries(player.global_position)])
	# Timed jumps: each jump made the moment after landing when the wire is coming back up
	var heights: Array[float] = []
	for jump in 6:
		var base := player.global_position.y
		# (wait for the bottom of its bounce under him, then jump)
		for _i in 40:
			await physics_frame
			if player.is_on_floor() and wire.spring_at(player.global_position).x > 0.05 and wire.spring_at(player.global_position).y >= 0.0:
				break
		Input.action_press(&"jump")
		player._queue_jump()
		var top := base
		var left := false
		for _i in 240:
			await physics_frame
			top = maxf(top, player.global_position.y)
			if not player.is_on_floor():
				left = true
			elif left:
				break
		Input.action_release(&"jump")
		heights.append(top - base)
		print("jump %d: %.2f m (on the wire %s)" % [jump, top - base, wire.carries(player.global_position)])
	var ok := shake < 0.08 and heights.max() > heights[0] + 1.5 and heights.max() < 7.0
	print("PASSED" if ok else "FAILED")
	quit()
