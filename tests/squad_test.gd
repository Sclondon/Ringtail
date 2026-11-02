extends SceneTree
## The raccoon squad (Squad, SquadRaccoon), headless in the playground: they stay near him as he runs about, keep
## apart, each goes off on its own errands some of the time, and they scatter from something chasing:
##   godot --headless --path . --audio-driver Dummy --fixed-fps 60 -s res://tests/squad_test.gd

var failures: Array[String] = []


func _initialize() -> void:
	var level: Node3D = (load("res://scenes/playground.tscn") as PackedScene).instantiate()
	root.add_child(level)
	_run.call_deferred(level)


func _check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)
	if not ok:
		failures.append(what)


func _run(level: Node3D) -> void:
	await physics_frame
	var player: Player = level.player
	player.global_position = Vector3(10.0, 0.05, -10.0)
	for _i in 10:
		await physics_frame
	Squad.place(level, player)
	var squad := level.get_node(^"Squad") as Squad
	_check(squad.members.size() == 5, "five in the squad")
	# A few things about to sniff at
	for k in 4:
		var crumb := Pickup.make(Pickup.Kind.CRUMB, Vector3(10.0 + k * 1.5, 0.0, -7.0))
		level.add_child(crumb)
	for _i in 60:
		await physics_frame

	# He runs about: forward, left, back, right, and stands
	var total := 0.0
	var samples := 0
	var closest := INF
	var away := {}
	var errands := {}
	for leg: StringName in [&"move_up", &"move_left", &"move_down", &"move_right", &""]:
		if leg != &"":
			# (a run, not a full push: full, he bounds off the end of the playground and they follow him off it)
			Input.action_press(leg, 0.7)
		for _i in (150 if leg != &"" else 300):
			await physics_frame
			for m in squad.members:
				var d := Vector2(m.global_position.x - player.global_position.x, m.global_position.z - player.global_position.z).length()
				total += d
				samples += 1
				if m.mind != SquadRaccoon.Mind.FOLLOW:
					errands[m] = errands.get(m, 0) + 1
				if m.global_position.distance_to(squad.slot(m.index)) > 1.2:
					away[m] = away.get(m, 0) + 1
			for a in squad.members:
				for b in squad.members:
					if a != b:
						closest = minf(closest, Vector2(a.global_position.x - b.global_position.x, a.global_position.z - b.global_position.z).length())
		if leg != &"":
			Input.action_release(leg)
	var mean := total / maxi(samples, 1)
	_check(mean < 3.0, "they stay near him (mean %.2f m)" % mean)
	_check(closest > 0.15, "they keep apart (closest %.2f m)" % closest)
	var own := 0
	for m in squad.members:
		if errands.get(m, 0) > 20 or away.get(m, 0) > 60:
			own += 1
	_check(own >= 3, "minds of their own (%d of 5 went off on their own)" % own)
	var sat := 0
	for m in squad.members:
		if m.sit_progress > 0.5:
			sat += 1
	_check(sat >= 2, "he stands still: they sit (%d)" % sat)

	# Something chasing comes among them: they scatter
	var pursuer := Node3D.new()
	pursuer.add_to_group(&"pursuers")
	level.add_child(pursuer)
	var middle := Vector3.ZERO
	for m in squad.members:
		middle += m.global_position
	middle /= squad.members.size()
	pursuer.global_position = middle
	var before := []
	for m in squad.members:
		before.append(m.global_position.distance_to(middle))
	for _i in 45:
		await physics_frame
	var fled := 0
	for k in squad.members.size():
		var m := squad.members[k]
		if m.mind == SquadRaccoon.Mind.SCATTER and m.global_position.distance_to(middle) > before[k] + 0.5:
			fled += 1
	_check(fled >= 4, "they scatter from a pursuer (%d of 5)" % fled)
	print("PASSED" if failures.is_empty() else "FAILED: " + ", ".join(failures))
	quit(0 if failures.is_empty() else 1)
