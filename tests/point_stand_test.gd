extends SceneTree
## Standing on one hand on a point (PointStand, PointPerches): the world has points (pole tops, tree tips); dropped
## from above onto a pole's top he catches it and balances there, out of reach of what hunts; jump throws him up
## off it. Prints PASSED or FAILED. Headless:
##   godot --headless --path . --audio-driver Dummy --fixed-fps 60 -s res://tests/point_stand_test.gd

var failures: Array[String] = []


func _initialize() -> void:
	var world: World = (load("res://scenes/world1.tscn") as PackedScene).instantiate()
	root.add_child(world)
	_run.call_deferred(world)


func _check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)
	if not ok:
		failures.append(what)


func _run(world: World) -> void:
	for _i in 30:
		await physics_frame
	var player := world.player
	var stand := player.get_node(^"PointStand") as PointStand
	_check(PointPerches.points.size() >= 4, "points to stand on (%d)" % PointPerches.points.size())
	# A pole's top: the point with the least drawn round it (a pole is thin; a tree's tip sits in leaves) - take the
	# one nearest 8.2 m over its ground
	var pole := Vector3.INF
	for p in PointPerches.points:
		var below := world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(p + Vector3(0.0, -0.5, 0.0), p + Vector3.DOWN * 40.0, 1))
		if not below.is_empty() and absf(p.y - (below.position as Vector3).y - 8.2) < 0.4:
			pole = p
			break
	if pole == Vector3.INF:
		pole = PointPerches.points[0]
	print("pole top at ", pole)
	player.global_position = pole + Vector3(0.15, 1.0, 0.1)
	player.velocity = Vector3.ZERO
	for _i in 60:
		await physics_frame
	_check(stand.on and player.global_position.distance_to(pole) < 0.05, "dropped onto a pole top, he stands on it on one hand")
	_check(Hazards.unseen(player), "nothing that hunts can get at him there")
	var rig := player.get_node(^"Rig") as RaccoonRig
	for _i in 30:
		await physics_frame
	_check(rig._hs_w > 0.9, "in the handstand pose (%.2f)" % rig._hs_w)
	# Jump: up off it
	Input.action_press(&"jump")
	var top := player.global_position.y
	for _i in 40:
		await physics_frame
		top = maxf(top, player.global_position.y)
	Input.action_release(&"jump")
	_check(not stand.on and top > pole.y + 0.8 and player.takes_input, "jump throws him up off it (%.2f m)" % (top - pole.y))
	# Scurrying up a pole to its top: he ends on it on one hand (first off the top he came back down onto)
	for _i in 40:
		await physics_frame
	if stand.on:
		stand._let_go()
	# (from the ground at its foot, facing it, the camera held behind him)
	var side := Vector3(0.0, 0.0, 0.45)
	var foot := world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(pole + side + Vector3.DOWN * 3.0, pole + side + Vector3.DOWN * 30.0, 1))
	player.global_position = (foot.position as Vector3) + Vector3.UP * 0.1 if not foot.is_empty() else pole + side + Vector3.DOWN * 8.0
	player.velocity = Vector3.ZERO
	player.facing_yaw = atan2(-side.x, -side.z)
	world.camera.set_process(false)
	world.camera.set_physics_process(false)
	world.camera.global_transform = Transform3D(Basis.looking_at(-side), player.global_position + side * 8.0 + Vector3.UP * 2.0)
	for _i in 10:
		await physics_frame
	var scurry := player.get_node(^"Scurry") as Scurry
	scurry.button = true
	Input.action_press(&"move_up")
	var climbed := false
	for _i in 600:
		await physics_frame
		if stand.on:
			climbed = true
			break
	Input.action_release(&"move_up")
	scurry.button = false
	_check(climbed, "scurrying up a pole, he ends on its top on one hand")
	print("PASSED" if failures.is_empty() else "FAILED: " + ", ".join(failures))
	quit()
