extends SceneTree
## The pee button (Pee): held, standing on the grove's lawn, he stands at it, the trickle runs and a puddle spreads;
## the stick aims it while he stays put; let go, he walks again; the puddle stays a while. Headless (with `-- --out=<dir>` in a window it shoots him at
## it from the side and behind):
##   godot --headless --path . --audio-driver Dummy --fixed-fps 60 -s res://tests/pee_test.gd

var failures: Array[String] = []
var out := ""


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
	var world: World = (load("res://scenes/world1.tscn") as PackedScene).instantiate()
	root.add_child(world)
	_run.call_deferred(world)


func _check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)
	if not ok:
		failures.append(what)


func _run(world: World) -> void:
	for _i in 60:
		await physics_frame
	var him := world.player
	var pee := him.get_node(^"Pee") as Pee
	var rig := him.get_node(^"Rig") as RaccoonRig
	Input.action_press(&"pee")
	for _i in 90:
		await physics_frame
	_check(pee.going and rig._pee_w > 0.8, "held, he stands at it (%.2f)" % rig._pee_w)
	_check(pee._stream.emitting, "the trickle runs")
	_check(pee._puddle != null and pee._puddle.scale.x > 0.05, "a puddle spreads")
	if out != "":
		for c in world.find_children("*", "CanvasLayer", true, false):
			c.visible = false
		# (alone: the villagers and the grass out of the way)
		for n in world.find_children("*", "Node3D", true, false):
			if n is Villager or n is MultiMeshInstance3D:
				n.visible = false
		var eye := Camera3D.new()
		world.add_child(eye)
		for k in 2:
			var from := (rig.global_basis.x.normalized() * -1.1 + rig.global_basis.z.normalized() * 0.5) if k == 0 else rig.global_basis.z.normalized() * 1.2
			eye.global_position = him.global_position + from + Vector3.UP * 0.35
			eye.look_at(him.global_position + Vector3.UP * 0.15 + rig.global_basis.z.normalized() * 0.3)
			eye.current = true
			for _i in 4:
				await process_frame
			root.get_viewport().get_texture().get_image().save_png("%s/pee_%d.png" % [out, k])
	# The stick aims it, he stays put
	var stood := him.global_position
	var was: Vector3 = pee._stream.direction
	Input.action_press(&"move_right", 1.0)
	for _i in 40:
		await physics_frame
	Input.action_release(&"move_right")
	_check(him.global_position.distance_to(stood) < 0.1, "he stays put while going")
	_check(pee._stream.direction.angle_to(was) > 0.4, "the stick aims it (%.2f rad)" % pee._stream.direction.angle_to(was))
	Input.action_release(&"pee")
	for _i in 5:
		await physics_frame
	_check(not pee.going and him.takes_input, "let go, he can walk again")
	for _i in 30:
		await physics_frame
	_check(rig._pee_w < 0.2, "let go, he is back to himself")
	_check(pee._puddle != null, "the puddle stays a while")
	print("PASSED" if failures.is_empty() else "FAILED: " + ", ".join(failures))
	quit()
