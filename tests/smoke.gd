extends SceneTree
## Loads World 1 and puts the raccoon through his moves and the world through its
## goals; prints PASSED or FAILED (and each check as it goes). Headless:
##   godot --headless --path . --audio-driver Dummy --fixed-fps 60 -s res://tests/smoke.gd

var world: World
var failures: Array[String] = []


func _initialize() -> void:
	world = (load("res://scenes/world1.tscn") as PackedScene).instantiate()
	root.add_child(world)
	_run.call_deferred()


func _check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)
	if not ok:
		failures.append(what)


func _frames(count: int) -> void:
	for _i in count:
		await physics_frame


func _release() -> void:
	for action: StringName in [&"move_up", &"move_down", &"duck", &"sprint", &"jump", &"tail"]:
		Input.action_release(action)


func _put(at: Vector3) -> void:
	_release()
	world.player.global_position = at
	world.player.velocity = Vector3.ZERO
	await _frames(20)


func _run() -> void:
	await _frames(10)
	var player := world.player
	var rig := player.get_node(^"Rig") as RaccoonRig
	var moves := player.get_node(^"TailMoves") as TailMoves
	_check(world.crumbs_total >= 90, "world has its Crumbs (%d)" % world.crumbs_total)
	_check(get_nodes_in_group(&"cats").size() == 3, "three cats in the yard")

	# Sprinting goes onto all fours
	await _put(Vector3(0.0, 0.05, 8.0))
	Input.action_press(&"move_up")
	Input.action_press(&"sprint")
	var most := 0.0
	for _i in 70:
		await physics_frame
		most = maxf(most, rig._quad)
	_check(most > 0.9 and rig._gallop > 0.5, "sprint on all fours (quad %.2f)" % most)

	# Duck-walking too
	await _put(Vector3(0.0, 0.05, 8.0))
	Input.action_press(&"duck")
	await _frames(10)
	Input.action_press(&"move_up", 0.7)
	await _frames(50)
	_check(rig._quad > 0.9 and rig._gallop < 0.2, "duck-walk on all fours (quad %.2f)" % rig._quad)

	# Jump held on the way down: the twirl, falling slowly
	await _put(Vector3(0.0, 0.05, 8.0))
	Input.action_press(&"jump")
	player._queue_jump()
	var glided := false
	var slowest := 0.0
	for _i in 60:
		await physics_frame
		if moves.gliding:
			glided = true
			slowest = minf(slowest, player.velocity.y)
	_check(glided and slowest > -moves.glide_fall - 0.6, "twirl slows the fall (%.2f m/s)" % slowest)

	# A tail whip at a cat beats it
	var cat := get_nodes_in_group(&"cats")[0] as YardCat
	cat.set_physics_process(false)
	# (behind it along the way he faces, so it is in front of him)
	var ahead := Vector3(sin(player.facing_yaw), 0.0, cos(player.facing_yaw))
	await _put(cat.global_position - ahead)
	ahead = Vector3(sin(player.facing_yaw), 0.0, cos(player.facing_yaw))
	player.global_position = cat.global_position - ahead
	await _frames(2)
	moves.press()
	await _frames(20)
	_check(cat.mode == YardCat.Mode.DAZED, "tail whip beats a cat")
	cat.set_physics_process(true)

	# A spin in the air
	await _put(Vector3(0.0, 0.05, 8.0))
	player._queue_jump()
	await _frames(12)
	moves.press()
	await _frames(3)
	_check(moves.spin < 1.0, "tail spin in the air")

	# Crumbs are taken by running into them
	var before := world.crumbs
	var crumb: Pickup
	for node in get_nodes_in_group(&"pickups"):
		if (node as Pickup).kind == Pickup.Kind.CRUMB:
			crumb = node
			break
	await _put(crumb.global_position)
	await _frames(5)
	_check(world.crumbs > before, "a Crumb taken")

	# Beating the other cats brings out their Bottlecap
	for other in get_nodes_in_group(&"cats"):
		if other != cat:
			(other as YardCat).tail_hit(Vector3.ZERO, Vector3.UP)
	await _frames(5)
	_check(_cap_out("cats"), "beating every cat brings out a Bottlecap")

	# The race: every race crumb in time brings out its Bottlecap
	world.race.start()
	await _frames(2)
	for node in get_nodes_in_group(&"pickups"):
		if (node as Pickup).kind == Pickup.Kind.RACE:
			(node as Pickup).take()
	await _frames(5)
	_check(_cap_out("race"), "winning the race brings out a Bottlecap")

	# Taking a Bottlecap counts it
	for node in get_nodes_in_group(&"pickups"):
		if (node as Pickup).kind == Pickup.Kind.CAP and (node as Pickup).tag == "roof":
			(node as Pickup).take()
	await _frames(5)
	_check(world.caps.has("roof"), "a Bottlecap taken")

	# A pounce hurts, and losing every heart sends him back
	world.hurt(player.global_position + Vector3.FORWARD)
	_check(world.hearts == World.MAX_HEARTS - 1, "hurt takes a heart")
	_release()
	print("PASSED" if failures.is_empty() else "FAILED: " + ", ".join(failures))
	quit(0 if failures.is_empty() else 1)


func _cap_out(called: String) -> bool:
	for node in get_nodes_in_group(&"pickups"):
		if (node as Pickup).kind == Pickup.Kind.CAP and (node as Pickup).tag == called:
			return true
	return false
