extends SceneTree
## Fishing at the grove's pond (PondFishing, GameCommon godot/fishing), in World 1: he walks up to the spot, the
## button comes up, he takes up the rod, casts, a fish bites (made to: FishingSpot.bite_now), he strikes, reels it
## in and lands it, and puts the rod away. With `-- --out=<dir>` (in a window) it also shoots the cast, the fight and
## the catch, and him holding the rod from four sides, above and close up.
##   godot --headless --path . --audio-driver Dummy --fixed-fps 60 -s res://tests/fishing_test.gd
##   godot --path . --audio-driver Dummy --resolution 1280x720 -s res://tests/fishing_test.gd -- --out=<dir>

var world: World
var failures: Array[String] = []
var out := ""


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
	if out != "":
		DirAccess.make_dir_recursive_absolute(out)
		root.position = Vector2i(-3000, 60)
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


func _shot(name: String) -> void:
	if out == "":
		return
	await process_frame
	await process_frame
	root.get_texture().get_image().save_png(out.path_join(name + ".png"))


func _run() -> void:
	await _frames(20)
	# (nothing to chase him, nor animals in the way; the pause menu kept shut)
	for node in get_nodes_in_group(&"hazards"):
		node.process_mode = Node.PROCESS_MODE_DISABLED
	var fishing := world.get_node_or_null(^"PondFishing") as PondFishing
	_check(fishing != null and fishing.spot != null, "a fishing spot by the pond")
	if fishing == null:
		_end()
		return
	var spot := fishing.spot
	# (driven by the test alone: a gamepad in use elsewhere reaches a window too)
	spot.main_actions = []
	spot.quit_actions = []
	var player := world.player
	# Walk up to it from 4 m back along the bank
	var back := -spot.global_basis.z
	var from := spot.global_position + back * 4.0
	var space := world.get_world_3d().direct_space_state
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from + Vector3.UP * 4.0, from + Vector3.DOWN * 4.0, 1, [player.get_rid()]))
	if not hit.is_empty():
		from = hit.position + Vector3.UP * 0.1
	player.global_position = from
	player.velocity = Vector3.ZERO
	player.facing_yaw = spot.global_rotation.y
	world.camera.look_along(spot.global_basis.z)
	world.camera.snap()
	await _frames(10)
	var came := false
	for _i in 400:
		# (pressed again every step: a window off the screen lets go of everything when it loses focus)
		Input.action_press(&"move_up", 0.7)
		await physics_frame
		if fishing.near():
			came = true
			break
	Input.action_release(&"move_up")
	_check(came, "walked up to the spot (%.1f m off)" % Vector2(player.global_position.x - spot.global_position.x, player.global_position.z - spot.global_position.z).length())
	await _frames(4)
	_check(fishing._prompt.visible, "the fishing button is on screen")
	await _shot("prompt")
	# Take up the rod (the button, as a touch would)
	fishing._prompt.pressed.emit()
	await _frames(30)
	_check(spot.running and player.carried is FishingRod, "he takes up the rod")
	_check(Player.input_blocked, "his own moves are off while fishing")
	var rig := player.get_node_or_null(^"Rig")
	_gaps("held")
	await _pose_shots("hold")
	# Cast: hold, let go
	spot.test_hold = true
	await _frames(40)
	await _shot("charging")
	spot.test_hold = false
	await _frames(8)
	await _shot("cast")
	await _frames(60)
	_check(spot.stage == FishingSpot.Stage.WAITING, "the bobber is out on the water (%s)" % FishingSpot.Stage.keys()[spot.stage])
	var bob := spot._bob_at
	_check(spot.is_water.call(bob.x, bob.z), "it landed in the pond (%.1f m out)" % Vector2(bob.x - spot.global_position.x, bob.z - spot.global_position.z).length())
	_gaps("waiting")
	await _pose_shots("wait")
	# A bite, struck
	spot.bite_now()
	await _frames(3)
	spot.test_hold = true
	for _i in 20:
		await process_frame
		if spot.stage == FishingSpot.Stage.FIGHT:
			break
	_check(spot.stage == FishingSpot.Stage.FIGHT, "hooked a fish")
	# Reel: in bursts, letting it slacken when the line gets tight
	var landed := [""]
	spot.caught.connect(func(kind: String, kg: float, record: bool) -> void:
		landed[0] = kind
		print("     caught %s, %.2f kg%s" % [kind, kg, " (record)" if record else ""]))
	var shot_fight := false
	for _i in 1800:
		spot.test_hold = spot.tension < 0.7
		await physics_frame
		if not shot_fight and spot.stage == FishingSpot.Stage.FIGHT and spot._stage_time > 0.6:
			shot_fight = true
			await _shot("fight")
			_gaps("fighting")
			await _pose_shots("fight")
		if spot.stage != FishingSpot.Stage.FIGHT:
			break
	spot.test_hold = false
	_check(landed[0] != "", "reeled it in and landed it (%s)" % (landed[0] if landed[0] != "" else FishingSpot.Stage.keys()[spot.stage]))
	if landed[0] != "":
		await _frames(30)
		await _shot("catch")
		_gaps("holding the catch")
		await _pose_shots("catch")
		_check(FishingSpot.best("grove_pond") > 0.0, "the best is kept (%.2f kg)" % FishingSpot.best("grove_pond"))
	# Put it away
	spot.quit()
	await _frames(10)
	_check(not spot.running and player.carried == null and not Player.input_blocked, "the rod put away, his moves back")
	_check(rig != null, "(his rig)")
	_end()


## How near the rod comes to his head and chest (m: from the bone to the rod between his hand and its tip).
func _gaps(name: String) -> void:
	var rig := world.player.get_node(^"Rig") as CharacterRig
	var skeleton := rig._skeleton
	var rod := world.player.carried as FishingRod
	if skeleton == null or rod == null:
		return
	var from := rod.global_position
	var to := rod.tip()
	var line := "     %s:" % name
	var worst := INF
	for bone: String in ["head", "neck", "chest", "spine"]:
		var k := skeleton.find_bone(bone)
		if k < 0:
			continue
		var at := skeleton.global_transform * skeleton.get_bone_global_pose(k).origin
		var d := at.distance_to(Geometry3D.get_closest_point_to_segment(at, from, to))
		line += "  %s %.2f" % [bone, d]
		if bone == "head":
			worst = d
	print(line)
	_check(worst > 0.1, "the rod clear of his head %s (%.2f m from its middle)" % [name, worst])


## Him with the rod from four sides, above and close up, by a camera of our own.
func _pose_shots(name: String) -> void:
	if out == "":
		return
	# (the fishing held still meanwhile)
	var spot := (world.get_node(^"PondFishing") as PondFishing).spot
	spot.process_mode = Node.PROCESS_MODE_DISABLED
	world.hud.visible = false
	spot.hud.visible = false
	# (and the others crowding round him out of the way)
	var others: Array[Node3D] = []
	for node in world.find_children("*", "CharacterBody3D", true, false):
		if (node is Villager or node is SquadRaccoon or node is Critter) and (node as Node3D).visible:
			others.append(node)
			(node as Node3D).visible = false
	var player := world.player
	var cam := Camera3D.new()
	cam.fov = 40.0
	world.add_child(cam)
	cam.current = true
	var at := player.global_position + Vector3.UP * 0.4
	var ahead := Vector3(sin(player.facing_yaw), 0.0, cos(player.facing_yaw))
	var left := Vector3.UP.cross(ahead)
	var views := {"front": ahead * 3.0 + Vector3.UP * 0.4, "back": -ahead * 3.0 + Vector3.UP * 0.8,
			"left": left * 3.0 + Vector3.UP * 0.4, "right": -left * 3.0 + Vector3.UP * 0.4,
			"above": Vector3.UP * 3.5 + ahead * 0.3, "close": (ahead + left) * 1.4 + Vector3.UP * 0.3, "catch": ahead * 4.0 + Vector3.UP * 0.6}
	for view: String in views:
		cam.global_position = at + views[view] * 0.7
		cam.look_at(at, Vector3.UP if view != "above" else ahead)
		await _shot(name + "_" + view)
	cam.queue_free()
	spot.process_mode = Node.PROCESS_MODE_INHERIT
	world.hud.visible = true
	spot.hud.visible = true
	for node in others:
		node.visible = true
	world.camera.current = true
	await process_frame


func _end() -> void:
	print("PASSED" if failures.is_empty() else "FAILED: " + ", ".join(failures))
	quit()
