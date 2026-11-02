extends SceneTree
## A dumpster (Dumpster) and a trash can on the grove's lawn: dropped over its open half he lands inside on its floor
## and takes the Crumbs there (each flying up over his head, then into him); dropped on its shut lid he stands on
## it; scurrying into a can knocks it over. Headless:
##   godot --headless --path . --audio-driver Dummy --fixed-fps 60 -s res://tests/dumpster_test.gd

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
	for _i in 20:
		await physics_frame
	var him := world.player
	var heart: Vector3 = world.markers["grove_heart"].origin if world.markers.has("grove_heart") else him.global_position
	var floor_y := _ground(him, heart + Vector3(6.0, 0.0, 6.0))
	var bin := Dumpster.new()
	bin.position = Vector3(heart.x + 6.0, floor_y, heart.z + 6.0)
	world.add_child(bin)
	var crumbs: Array[Pickup] = []
	for spot in bin.inside():
		var crumb := Pickup.make(Pickup.Kind.CRUMB, spot)
		world.add_child(crumb)
		crumbs.append(crumb)
	await physics_frame
	# Into the open (left) half
	him.global_position = bin.global_transform * Vector3(-0.45, 2.0, 0.0)
	him.velocity = Vector3.ZERO
	for _i in 90:
		await physics_frame
	var local := bin.global_transform.affine_inverse() * him.global_position
	_check(absf(local.x) < 0.9 and absf(local.z) < 0.55 and local.y < 0.5, "he lands inside it (%s)" % local)
	# Walk along its floor to take them all
	for k in 120:
		Input.action_press(&"move_right" if k < 60 else &"move_left", 0.5)
		await physics_frame
	Input.action_release(&"move_right")
	Input.action_release(&"move_left")
	var flying := false
	var taken := 0
	for crumb in crumbs:
		if not is_instance_valid(crumb) or crumb._gone >= 0.0:
			taken += 1
	_check(taken >= 2, "he takes the Crumbs in it (%d of %d)" % [taken, crumbs.size()])
	# Taken: up over his head first
	var fresh := Pickup.make(Pickup.Kind.CRUMB, him.global_position + Vector3(0.0, 0.0, 0.0))
	world.add_child(fresh)
	fresh.take(him)
	for _i in 20:
		await physics_frame
	flying = is_instance_valid(fresh) and fresh.global_position.y > him.global_position.y + 0.7
	_check(flying, "a taken Crumb rises over his head")
	for _i in 60:
		await physics_frame
	_check(not is_instance_valid(fresh) or not fresh._spin.visible, "then flies into him and is gone")
	# On the shut (right) lid
	him.global_position = bin.global_transform * Vector3(0.45, 2.0, 0.0)
	him.velocity = Vector3.ZERO
	for _i in 90:
		await physics_frame
	local = bin.global_transform.affine_inverse() * him.global_position
	_check(local.y > 1.1, "he stands on its shut lid (%.2f)" % local.y)
	# A trash can, scurried into
	var can := TrashCan.make(null)
	var can_at := heart + Vector3(-6.0, 0.0, 6.0)
	can.position = Vector3(can_at.x, _ground(him, can_at), can_at.z)
	world.add_child(can)
	var right := him.get_viewport().get_camera_3d().global_basis.x.slide(Vector3.UP).normalized()
	him.global_position = can.position - right * 3.0 + Vector3.UP * 0.3
	him.velocity = Vector3.ZERO
	for _i in 10:
		await physics_frame
	for _i in 90:
		Input.action_press(&"scurry")
		var cam := him.get_viewport().get_camera_3d().global_basis
		var want := (can.global_position - him.global_position).slide(Vector3.UP).normalized()
		var sx := want.dot(cam.x.slide(Vector3.UP).normalized())
		var sy := -want.dot(-cam.z.slide(Vector3.UP).normalized())
		for pair: Array in [[&"move_right", sx], [&"move_left", -sx], [&"move_down", sy], [&"move_up", -sy]]:
			if pair[1] > 0.0: Input.action_press(pair[0], pair[1])
			else: Input.action_release(pair[0])
		await physics_frame
		if can.tipped:
			break
	Input.action_release(&"scurry")
	for action: StringName in [&"move_right", &"move_left", &"move_up", &"move_down"]:
		Input.action_release(action)
	for _i in 60:
		await physics_frame
	_check(can.tipped, "scurrying into a can knocks it over")
	print("PASSED" if failures.is_empty() else "FAILED: " + ", ".join(failures))
	quit()


func _ground(him: Node3D, at: Vector3) -> float:
	var query := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 30.0, at + Vector3.DOWN * 30.0, 1)
	var hit := him.get_world_3d().direct_space_state.intersect_ray(query)
	return (hit.position as Vector3).y if hit else at.y
