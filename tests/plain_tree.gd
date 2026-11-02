extends SceneTree
## A plain tree of the town (a treep_ marker: a cedar, then an oak): walking into it stops him, and scurrying into it
## he climbs its trunk up into the crown and hops off on top (the user, 2026-11-02: "pine trees need collision and
## should be climbable"). Prints each and PASSED/FAILED. Headless:
##   godot --headless --path . --audio-driver Dummy --fixed-fps 60 -s res://tests/plain_tree.gd

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


func _run() -> void:
	await _frames(10)
	var player := world.player
	var scurry := player.get_node(^"Scurry") as Scurry
	for node in get_nodes_in_group(&"hazards"):
		node.process_mode = Node.PROCESS_MODE_DISABLED
	world.camera.set_process(false)
	world.camera.set_physics_process(false)
	for kind: String in ["fir", "maplelo"]:
		var at := Vector3.INF
		# (the one furthest from the giant firs' leafy platforms, so he does not come down onto one)
		var clear := -1.0
		for name: String in world.markers:
			if name.begins_with("treep_") and name.ends_with("_" + kind) and (world.markers[name].origin as Vector3).y > 0.5:
				var here: Vector3 = world.markers[name].origin
				var room := INF
				for other: String in world.markers:
					if other.begins_with("npc_perch_") or other.begins_with("giantfir_"):
						var p: Vector3 = world.markers[other].origin
						room = minf(room, Vector2(p.x - here.x, p.z - here.z).length())
				if room > clear:
					clear = room
					at = here
		if at == Vector3.INF:
			_check(false, "a plain %s in the world" % kind)
			continue
		# (from the clearing's side of it)
		var away := Vector3(-at.x, 0.0, -at.z).normalized()
		# Walking into it: he stops at its trunk
		Input.action_release(&"move_up")
		scurry.button = false
		player.velocity = Vector3.ZERO
		player.global_position = at + away * 2.0 + Vector3.UP * 0.3
		player.facing_yaw = atan2(-away.x, -away.z)
		await _frames(20)
		world.camera.global_transform = Transform3D(Basis.looking_at(-away), at + away * 6.0 + Vector3.UP * 2.0)
		Input.action_press(&"move_up")
		var nearest := INF
		for _i in 90:
			await physics_frame
			nearest = minf(nearest, Vector2(player.global_position.x - at.x, player.global_position.z - at.z).length())
		Input.action_release(&"move_up")
		_check(nearest > 0.2, "walking into a %s stops at its trunk (%.2f m from its middle)" % [kind, nearest])
		# Scurrying into it: up the trunk and off on top
		player.velocity = Vector3.ZERO
		player.global_position = at + away * 1.0 + Vector3.UP * 0.3
		await _frames(20)
		scurry.button = true
		Input.action_press(&"move_up")
		var climbed := false
		var highest := player.global_position.y
		for _i in 600:
			await physics_frame
			climbed = climbed or scurry.climbing
			highest = maxf(highest, player.global_position.y)
			# (the camera kept behind him, looking in at the tree, as the follow camera would)
			var out := Vector3(player.global_position.x - at.x, 0.0, player.global_position.z - at.z)
			if out.length() > 0.3:
				out = out.normalized()
				world.camera.global_transform = Transform3D(Basis.looking_at(-out), player.global_position + out * 4.0 + Vector3.UP * 2.0)
			if climbed and not scurry.climbing and player.is_on_floor():
				break
		Input.action_release(&"move_up")
		scurry.button = false
		await _frames(30)
		_check(climbed and highest - at.y > 3.0 and player.global_position.y > highest - 1.0, "scurries up a %s and stands on top (%.1f m up, stood at %.1f m)" % [kind, highest - at.y, player.global_position.y - at.y])
	print("PASSED" if failures.is_empty() else "FAILED: " + ", ".join(failures))
	quit(0 if failures.is_empty() else 1)
