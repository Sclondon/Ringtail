extends SceneTree
## Scurries up drainpipes (the user, 2026-11-02: "there needs to be drains and gutter pipes to scurry up"; "need to be
## easier to climb"): a ring house's, a hillside house's, a block of flats', a shop's, a back-row house's, the bath
## house's, each from three angles. He is put in front of the pipe, scurry held and the stick pushed at it; he should
## climb to the roof's edge and hop over onto it. Prints each and PASSED/FAILED. Headless:
##   godot --headless --path . --audio-driver Dummy --fixed-fps 60 -s res://tests/pipe_climb.gd

const PIPES := ["house_5", "hill_house_1", "danchi_6", "shop_4", "back_8_0", "sento_0"]
const ANGLES := [-0.6, 0.0, 0.6]

var world: World
var failures: Array[String] = []


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
	var scurry := player.get_node(^"Scurry") as Scurry
	# (the hazards out of the way)
	for node in get_nodes_in_group(&"hazards"):
		node.process_mode = Node.PROCESS_MODE_DISABLED
	world.camera.set_process(false)
	world.camera.set_physics_process(false)
	for building: String in PIPES:
		var pipe := world.find_child("climb_pipes_%s_hidden" % building, true, false) as MeshInstance3D
		var house := world.find_child(building, true, false) as MeshInstance3D
		if pipe == null or house == null:
			failures.append(building + " missing")
			print("FAIL ", building, " missing")
			continue
		# (the first pipe's foot: the lowest points near the mesh's first point)
		var points: PackedVector3Array = pipe.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		var first := pipe.global_transform * points[0]
		var foot := INF
		var top := -INF
		for p in points:
			var g := pipe.global_transform * p
			if Vector2(g.x - first.x, g.z - first.z).length() < 1.5:
				foot = minf(foot, g.y)
				top = maxf(top, g.y)
		var at := Vector3.ZERO
		var count := 0
		for p in points:
			var g := pipe.global_transform * p
			if Vector2(g.x - first.x, g.z - first.z).length() < 1.5 and g.y < foot + 0.05:
				at += g
				count += 1
		at /= count
		var centre := (house.global_transform * house.get_aabb()).get_center()
		var out := Vector3(at.x - centre.x, 0.0, at.z - centre.z).normalized()
		for turn: float in ANGLES:
			var away := out.rotated(Vector3.UP, turn)
			Input.action_release(&"move_up")
			scurry.button = false
			player.velocity = Vector3.ZERO
			player.global_position = at + away * 0.6 + Vector3.UP * 0.15
			player.facing_yaw = atan2(-away.x, -away.z)
			await _frames(20)
			world.camera.global_transform = Transform3D(Basis.looking_at(-away), at + away * 4.0 + Vector3.UP * 2.0)
			scurry.button = true
			Input.action_press(&"move_up")
			var climbed := false
			var highest := player.global_position.y
			for _i in 480:
				await physics_frame
				climbed = climbed or scurry.climbing
				highest = maxf(highest, player.global_position.y)
				if not scurry.climbing and climbed and player.is_on_floor():
					break
			Input.action_release(&"move_up")
			scurry.button = false
			await _frames(30)
			var landed := player.global_position.y
			var ok := climbed and landed > top - 1.0 and player.is_on_floor()
			print(("ok   " if ok else "FAIL "), building, " from %+.1f: climbed %s, roof edge %.1f, highest %.1f, stood at %.1f" % [turn, climbed, top, highest, landed])
			if not ok:
				failures.append("%s %+.1f" % [building, turn])
	print("PASSED" if failures.is_empty() else "FAILED: " + ", ".join(failures))
	quit(0 if failures.is_empty() else 1)
