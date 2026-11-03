extends SceneTree
## The town's raccoons' gaits (the user, 2026-11-02: "raccoons should walk around on all 4s too sometimes"): a grown-up
## and a kit strolling upright and on all fours across the playground, measured as tests/gait_check.gd measures him:
## how far a foot or paw slides while it is down, how low it goes. Headless:
##   godot --headless --path . --audio-driver Dummy --fixed-fps 60 -s res://tests/villager_gait_check.gd

const FRAMES := 120
var failures: Array[String] = []


func _initialize() -> void:
	var level: Node3D = load("res://scenes/playground.tscn").instantiate()
	root.add_child(level)
	_run.call_deferred(level)


func _run(level: Node3D) -> void:
	# (baked figures stepped every frame, however far from the camera: their feet measured frame by frame)
	BakedMotion.full_rate = true
	for _i in 10:
		await physics_frame
	var player: Player = level.player
	var band := Villagers.new()
	band.player = player
	level.add_child(band)
	band.talk = Chatter.new()
	band.talk.villagers = band
	band.add_child(band.talk)
	for case: Array in [["adult upright", false, false], ["adult fours", false, true], ["kit upright", true, false], ["kit fours", true, true]]:
		var who := band._add(case[1], 3, Vector3(-14.0, 0.3, 14.0), {})
		# (him near, so its rig is awake, but out of its way)
		player.global_position = Vector3(-6.0, 0.1, 22.0)
		for _i in 20:
			await physics_frame
		who._go(Villager.Doing.STROLL, 60.0)
		who.rig.always_on_fours = case[2]
		who._goal = Vector3(14.0, 0.0, -14.0)
		who._pace = 0.35
		for _i in 60:
			await physics_frame
		# (the skeleton's own feet and hands: posed live or played from baked clips, BakedMotion)
		var skeleton: Skeleton3D = who.rig._skeleton
		var parts: Array[int] = []
		for bone: String in ["foot_l", "foot_r", "hand_l", "hand_r"]:
			parts.append(skeleton.find_bone(bone))
		var track: Array = []
		var speed := 0.0
		for _i in FRAMES:
			await physics_frame
			speed += Vector2(who.velocity.x, who.velocity.z).length() / FRAMES
			var frame: Array[Vector3] = []
			for part in parts:
				frame.append(skeleton.global_transform * skeleton.get_bone_global_pose(part).origin - Vector3(0.0, who.global_position.y, 0.0))
			track.append(frame)
		var slip := [0.0, 0.0, 0.0, 0.0]
		var lowest := [INF, INF, INF, INF]
		for k in parts.size():
			for frame: Array in track:
				lowest[k] = minf(lowest[k], frame[k].y)
			var down_at = null
			for frame: Array in track:
				var at: Vector3 = frame[k]
				if at.y < lowest[k] + 0.004:
					if down_at == null:
						down_at = at
					slip[k] = maxf(slip[k], Vector2(at.x - down_at.x, at.z - down_at.z).length())
				else:
					down_at = null
		var baked := who.rig.get_node_or_null(^"Baked") != null
		var on_fours: bool = who.rig.always_on_fours if baked else who.rig._quad > 0.5
		# (feet always; paws only when they walk on them)
		var worst := maxf(slip[0], slip[1])
		if on_fours:
			worst = maxf(worst, maxf(slip[2], slip[3]))
		print("%-13s %s speed %.2f m/s quad %.2f slip hind %.3f %.3f fore %.3f %.3f m (scale %.2f)" % [case[0], "baked" if baked else "live ", speed, who.rig._quad, slip[0], slip[1], slip[2], slip[3], who.rig.scale.x])
		# (a kit drops to all fours to go any faster than a walk, upright or not)
		var ok: bool = (on_fours == case[2] or case[1]) and worst < 0.04 * maxf(who.rig.scale.x, 0.5) * 2.0 and speed > 0.3
		print(("ok   " if ok else "FAIL ") + case[0])
		if not ok:
			failures.append(case[0])
		who.queue_free()
		band.members.erase(who)
		await physics_frame
	print("PASSED" if failures.is_empty() else "FAILED: " + ", ".join(failures))
	quit()
