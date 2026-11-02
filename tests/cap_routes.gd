extends SceneTree
## Walks the Bottlecaps' routes that are his to make (the cats' and the race's are in smoke.gd): up the bath house
## chimney on the Estate face (scurry), the glide from the hilltop flats to the billboard on the Stairs face (jump,
## jump again to twirl, glide), into the hollow log in the Shrine face's bamboo (crawl in). Prints each and
## PASSED/FAILED. Headless:
##   godot --headless --path . --audio-driver Dummy --fixed-fps 60 -s res://tests/cap_routes.gd

var world: World
var failures: Array[String] = []


func _initialize() -> void:
	world = (load("res://scenes/world1.tscn") as PackedScene).instantiate()
	root.add_child(world)
	_run.call_deferred()


func _frames(count: int) -> void:
	for _i in count:
		await physics_frame


func _check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)
	if not ok:
		failures.append(what)


func _release() -> void:
	for action: StringName in [&"move_up", &"jump", &"duck"]:
		Input.action_release(action)
	(world.player.get_node(^"Scurry") as Scurry).button = false


## Puts him at `at` facing `towards`, the camera behind him looking the same way.
func _put(at: Vector3, towards: Vector3) -> void:
	_release()
	var player := world.player
	player.velocity = Vector3.ZERO
	player.global_position = at
	var way := Vector3(towards.x - at.x, 0.0, towards.z - at.z).normalized()
	player.facing_yaw = atan2(way.x, way.z)
	world.camera.global_transform = Transform3D(Basis.looking_at(way), at - way * 4.0 + Vector3.UP * 2.0)
	await _frames(20)


func _cap(called: String) -> Vector3:
	return world.markers["cap_" + called].origin


func _run() -> void:
	await _frames(10)
	var player := world.player
	for node in get_nodes_in_group(&"hazards"):
		node.process_mode = Node.PROCESS_MODE_DISABLED
	world.camera.set_process(false)
	world.camera.set_physics_process(false)

	# Up the chimney: scurry up it from its foot, over the top onto its cap
	var cap := _cap("roof")
	var foot := Vector3(cap.x, 0.0, cap.z)
	var space := world.get_world_3d().direct_space_state
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(foot + Vector3(0.0, cap.y - 1.0, 2.0), foot + Vector3(0.0, -80.0, 2.0), 1, [player.get_rid()]))
	var ground := (hit.position as Vector3).y if not hit.is_empty() else cap.y - 16.0
	await _put(Vector3(cap.x, ground + 0.2, cap.z + 1.3), foot)
	(player.get_node(^"Scurry") as Scurry).button = true
	Input.action_press(&"move_up")
	var nearest := INF
	for _i in 600:
		await physics_frame
		nearest = minf(nearest, player.global_position.distance_to(cap))
		if nearest < 0.8:
			break
	_release()
	_check(nearest < 0.8, "up the chimney to its Bottlecap (came within %.1f m)" % nearest)

	# The glide: from the back of the hilltop flats' roof, jump, jump again to twirl, and glide to the billboard
	cap = _cap("glide")
	var flats := world.find_child("danchi_10", true, false) as MeshInstance3D
	var box := flats.global_transform * flats.get_aabb()
	var roof_top := box.end.y - 3.0
	var middle := box.get_center()
	var launch := Vector3(middle.x, roof_top, middle.z)
	# (from the side of its roof nearest the billboard)
	var to_cap := Vector3(cap.x - middle.x, 0.0, cap.z - middle.z).normalized()
	launch += to_cap * 4.0
	hit = space.intersect_ray(PhysicsRayQueryParameters3D.create(launch + Vector3.UP * 4.0, launch + Vector3.DOWN * 6.0, 1, [player.get_rid()]))
	if not hit.is_empty():
		launch = hit.position + Vector3.UP * 0.1
	await _put(launch, cap)
	Input.action_press(&"move_up")
	await _frames(10)
	player._queue_jump()
	Input.action_press(&"jump")
	await _frames(14)
	Input.action_release(&"jump")
	await _frames(4)
	player._queue_jump()
	Input.action_press(&"jump")
	nearest = INF
	var landed_y := -INF
	for _i in 900:
		await physics_frame
		var way := Vector3(cap.x - player.global_position.x, 0.0, cap.z - player.global_position.z)
		# (steered at the billboard, as a player would)
		if way.length() > 0.5:
			world.camera.global_transform = Transform3D(Basis.looking_at(way.normalized()), player.global_position - way.normalized() * 4.0 + Vector3.UP * 2.0)
		nearest = minf(nearest, player.global_position.distance_to(cap))
		if player.is_on_floor():
			landed_y = player.global_position.y
			break
	_release()
	_check(nearest < 1.2, "glides from the hilltop flats to the billboard's Bottlecap (came within %.1f m, landed at %.1f, the cap at %.1f)" % [nearest, landed_y, cap.y])

	# The hollow log: crawl in at one end to the Bottlecap in its middle
	cap = _cap("hidden")
	var log_mesh := world.find_child("log", true, false) as MeshInstance3D
	var log_box := log_mesh.global_transform * log_mesh.get_aabb()
	var along := Vector3(1.0, 0.0, 0.0) if log_box.size.x > log_box.size.z else Vector3(0.0, 0.0, 1.0)
	var start := Vector3(cap.x, cap.y, cap.z) + along * 3.0
	await _put(start + Vector3.UP * 0.3, cap)
	Input.action_press(&"duck")
	await _frames(10)
	Input.action_press(&"move_up")
	nearest = INF
	for _i in 300:
		await physics_frame
		nearest = minf(nearest, player.global_position.distance_to(cap))
	_release()
	_check(nearest < 0.7, "crawls into the log to its Bottlecap (came within %.1f m)" % nearest)
	print("PASSED" if failures.is_empty() else "FAILED: " + ", ".join(failures))
	quit(0 if failures.is_empty() else 1)
