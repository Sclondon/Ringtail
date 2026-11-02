extends SceneTree
## Measures the raccoon's legs through each move, frame by frame, for what reads as a broken leg (the user,
## 2026-11-02: "lots of the poses break his legs it looks like"): a knee bent backwards (behind the line from hip to
## ankle, against the way he faces), a leg stretched past its length or crushed short, a foot sunk under the ground,
## a foot turned back, and a knee flipping across from one frame to the next. Prints one line a move; with `all` it
## prints each bad frame too. Headless:
##   godot --headless --path . --audio-driver Dummy --fixed-fps 60 -s res://tests/leg_check.gd -- [moves...] [all]

const MOVES := ["stand", "walk", "sneak", "run", "bound", "scurry", "duck", "duckwalk", "jump", "flip", "fall", "spin",
		"spin_jump", "heli", "long_jump", "slide", "climb", "hang", "wire", "sit"]

var player: Player
var rig: RaccoonRig
var level: Node3D
var only: Array[String] = []
var verbose := false
var failures: Array[String] = []


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg == "all":
			verbose = true
		else:
			only.append(arg)
	level = load("res://scenes/playground.tscn").instantiate()
	root.add_child(level)
	_run.call_deferred()


func _frames(count: int) -> void:
	for _i in count:
		await physics_frame


func _release() -> void:
	(player.get_node(^"Scurry") as Scurry).button = false
	for action: StringName in [&"move_up", &"duck", &"jump", &"tail", &"move_left"]:
		Input.action_release(action)


func _run() -> void:
	await process_frame
	player = level.player
	rig = player.get_node(^"Rig") as RaccoonRig
	for move: String in MOVES:
		if only.is_empty() or move in only:
			await _do(move)
	print("LEGS PASSED" if failures.is_empty() else "LEGS FAILED: " + ", ".join(failures))
	quit()


## Puts him through `move` and watches his legs for `watch` frames once it is going.
func _do(move: String) -> void:
	_release()
	player.state = Player.State.FREE
	player.global_position = Vector3(12.0, 0.05, -12.0)
	player.velocity = Vector3.ZERO
	player.facing_yaw = 0.0
	await _frames(40)
	var watch := 90
	match move:
		"stand":
			pass
		"walk":
			Input.action_press(&"move_up", 0.6)
			await _frames(30)
		"sneak":
			Input.action_press(&"move_up", 0.25)
			await _frames(30)
		"run":
			Input.action_press(&"move_up", 0.9)
			await _frames(30)
		"bound":
			Input.action_press(&"move_up", 1.0)
			await _frames(30)
		"scurry":
			(player.get_node(^"Scurry") as Scurry).button = true
			Input.action_press(&"move_up", 1.0)
			await _frames(30)
		"duck":
			Input.action_press(&"duck")
			await _frames(20)
		"duckwalk":
			Input.action_press(&"duck")
			await _frames(10)
			Input.action_press(&"move_up", 0.8)
			await _frames(30)
		"jump":
			Input.action_press(&"jump")
			player._queue_jump()
			watch = 60
		"flip":
			Input.action_press(&"duck")
			await _frames(15)
			Input.action_press(&"jump")
			player._queue_jump()
			watch = 70
		"fall":
			player.global_position.y += 6.0
			watch = 80
		"spin":
			Input.action_press(&"tail")
			watch = 45
		"spin_jump":
			Input.action_press(&"move_up", 1.0)
			await _frames(5)
			player.is_spinning = true
			player._spin_speed = 20.0
			await _frames(5)
			Input.action_release(&"move_up")
			player._queue_jump()
			watch = 120
		"heli":
			Input.action_press(&"jump")
			player._queue_jump()
			await _frames(15)
			player._queue_jump()
			await _frames(15)
			watch = 50
		"long_jump":
			Input.action_press(&"move_up", 1.0)
			await _frames(45)
			Input.action_press(&"duck")
			await _frames(3)
			player._queue_jump()
			watch = 60
		"slide":
			Input.action_press(&"move_up", 1.0)
			await _frames(45)
			Input.action_press(&"duck")
			watch = 40
		"climb":
			# (up something climbable: the playground's pole, if it has one, else skip)
			var pole := _climbable()
			if pole == Vector3.INF:
				print("%-10s (nothing to climb here)" % move)
				return
			player.global_position = pole + Vector3(0.0, 0.05, -0.55)
			player.facing_yaw = 0.0
			(player.get_node(^"Scurry") as Scurry).button = true
			Input.action_press(&"move_up", 1.0)
			await _frames(20)
			watch = 90
		"hang", "wire", "sit":
			if move == "sit":
				watch = 150
			else:
				print("%-10s (not set up in the playground)" % move)
				return
	await _watch(move, watch)
	_release()


func _climbable() -> Vector3:
	for node in get_nodes_in_group(&"climbable"):
		if node is Node3D and (node as Node3D).global_position.length() > 0.5:
			return (node as Node3D).global_position
	return Vector3.INF


func _watch(move: String, frames: int) -> void:
	var worst_back := 0.0
	var worst_stretch := 0.0
	var worst_crush := 9.0
	var worst_sink := 0.0
	var worst_twist := 0.0
	var flips := 0
	var was_side := [0.0, 0.0]
	var bad_frames := 0
	for f in frames:
		await physics_frame
		# (his body's own front, from his hips, upright: not the rig's, which a back tuck leaves behind; on all fours, the
		# rig's, his hips being pitched right over)
		var fwd := (rig.global_basis.z if rig._quad > 0.5 else rig._hips.global_basis.z).normalized()
		var size := rig.global_basis.get_scale().y
		var full := (rig._thigh + rig._shin) * size
		var bad := ""
		for i in 2:
			var hip := rig._thighs[i].global_position
			var knee := rig._shins[i].global_position
			var ankle := rig._feet[i].global_position
			var toe := rig._toes[i].global_position
			var line := ankle - hip
			var reach := line.length()
			var t := clampf((knee - hip).dot(line) / maxf(line.length_squared(), 0.0001), 0.0, 1.0)
			var bend := knee - (hip + line * t)
			# (backwards: the knee behind the hip-ankle line, against the way he faces, by more than 3 cm: a dangling leg leans
			# that far without looking wrong)
			var back := -bend.dot(fwd)
			worst_back = maxf(worst_back, back)
			worst_stretch = maxf(worst_stretch, reach / full)
			worst_crush = minf(worst_crush, reach / full)
			var ground := player.global_position.y if player.is_on_floor() else -INF
			var sink := ground - minf(ankle.y, toe.y)
			if ground > -INF:
				worst_sink = maxf(worst_sink, sink)
			var foot := Vector3(toe.x - ankle.x, 0.0, toe.z - ankle.z)
			# (only a foot lying out, not one hanging toes down)
			var twist := rad_to_deg(foot.angle_to(Vector3(fwd.x, 0.0, fwd.z))) if foot.length() > 0.045 * size else 0.0
			worst_twist = maxf(worst_twist, twist)
			# (which way across the knee points: flipping from one side to the other from frame to frame)
			var side := bend.dot(rig.global_basis.x.normalized()) * (1.0 if i == 0 else -1.0)
			if f > 0 and absf(side - float(was_side[i])) > 0.06 and signf(side) != signf(float(was_side[i])):
				flips += 1
				bad += " flip%d(%.3f->%.3f)" % [i, float(was_side[i]), side]
			was_side[i] = side
			if back > 0.03:
				bad += " back%d=%.3f" % [i, back]
			if reach / full > 1.02:
				bad += " stretch%d=%.2f" % [i, reach / full]
			if ground > -INF and sink > 0.03:
				bad += " sink%d=%.3f" % [i, sink]
			if twist > 100.0 and player.is_on_floor():
				bad += " twist%d=%.0f" % [i, twist]
		if bad != "":
			bad_frames += 1
			if verbose:
				print("  %s f%d:%s" % [move, f, bad])
	var ok := worst_back <= 0.03 and worst_stretch <= 1.02 and worst_sink <= 0.03 and flips == 0
	print("%-10s back %.3f  stretch %.2f  crush %.2f  sink %.3f  twist %3.0f  flips %d  bad frames %d/%d %s" % [move, worst_back, worst_stretch, worst_crush, worst_sink, worst_twist, flips, bad_frames, frames, "" if ok else "<<"])
	if not ok:
		failures.append(move)
