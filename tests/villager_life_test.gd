extends SceneTree
## The raccoons of the grove living their lives: two grown-ups chat (turn about, the talker gesturing and the other
## listening; with him near, what they say shows over them, one bubble at a time), a kit goes up a tree and comes down
## again, and the kits play. Prints PASSED or FAILED. Headless:
##   godot --headless --path . --audio-driver Dummy --fixed-fps 60 -s res://tests/villager_life_test.gd

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
	var band := world.get_node(^"Villagers") as Villagers
	var grove := band.members.filter(func(m: Villager) -> bool: return m.home != Vector3.INF and not m.stays)
	var adults := grove.filter(func(m: Villager) -> bool: return not m.kit)
	var kits := grove.filter(func(m: Villager) -> bool: return m.kit)
	var player := world.player
	# (him well off, out of the way, while they get on with it)
	player.global_position = (adults[0] as Villager).home + Vector3(0.0, 0.5, 5.5)

	# A chat
	var a: Villager = adults[0]
	var b: Villager = adults[1]
	# (everyone else held still meanwhile, so the scene is only these two and him)
	_only(band, [a, b])
	# (and the others quiet: one near him would be talking to him, and a chat does not show over that)
	var kept_lines := {}
	for member in band.members:
		if member != a and member != b:
			kept_lines[member] = member.lines
			member.lines = PackedStringArray()
	# (the two set down a little apart at their place, him a few steps off)
	for k in 2:
		var who: Villager = [a, b][k]
		who.global_position = who.home + Vector3(-1.2 + 2.4 * k, 0.4, 0.0)
		who.velocity = Vector3.ZERO
		who._go(Villager.Doing.STAND, 30.0)
	# (him a few steps off the pair, on the side away from the middle of the grove where the kits are)
	var pair_mid := (a.home + b.home) * 0.5
	var away := Vector3(pair_mid.x - band.members.filter(func(m: Villager) -> bool: return m.kit and m.home != Vector3.INF)[0].home.x, 0.0, pair_mid.z - band.members.filter(func(m: Villager) -> bool: return m.kit and m.home != Vector3.INF)[0].home.z)
	player.global_position = pair_mid + (away.normalized() if away.length() > 0.1 else Vector3.BACK) * 4.0 + Vector3.UP * 0.5
	for _i in 10:
		await physics_frame
	band.start_chat(a, b)
	var speakers := {}
	var ended_as := -1
	var gestured := false
	var listened := false
	var shown := 0
	var busy_frames := 0
	var most_open := 0
	for _i in 600:
		await physics_frame
		if a.doing != Villager.Doing.CHAT:
			ended_as = a.doing
			break
		if a._at(a.chat_spot, 0.3) and b._at(b.chat_spot, 0.3):
			speakers[a.speaking] = true
			var talker: Villager = a if a.speaking else b
			var hearer: Villager = b if a.speaking else a
			gestured = gestured or talker.rig._talk_w > 0.6
			listened = listened or hearer.rig._listen_w > 0.6
		var open := 0
		for who: Villager in [a, b]:
			if band.talk._bubbles.has(who) and band.talk._bubbles[who].openness > 0.5:
				open += 1
		most_open = maxi(most_open, open)
		shown += 1 if open > 0 else 0
		busy_frames += 1 if band.talk.busy() else 0
	for member in kept_lines:
		member.lines = kept_lines[member]
	_check(speakers.size() == 2, "two grown-ups chat, turn about (it ended as %s)" % (Villager.Doing.keys()[ended_as] if ended_as >= 0 else "still chatting"))
	_check(gestured and listened, "the one talking gestures, the other listens")
	_check(shown > 30 and most_open == 1, "with him near, what they say shows over them, one bubble at a time (shown %d frames, at most %d at once, he was talked to %d frames)" % [shown, most_open, busy_frames])

	# Up a tree and down again
	player.global_position = (adults[0] as Villager).home + Vector3(0.0, 0.5, 9.0)
	var climber: Villager = kits[0]
	_only(band, [climber])
	climber.playmate = null
	# (a few goes: a tree whose foot it cannot reach it gives up)
	var went := false
	for _try in 3:
		climber._go(Villager.Doing.STAND, 30.0)
		went = climber._begin_climb()
		for _i in 600:
			await physics_frame
			if climber.doing != Villager.Doing.CLIMB or climber._climb_phase > 0:
				break
		if climber._climb_phase > 0:
			break
	var base_y := climber._tree.global_position.y if went else 0.0
	var highest := 0.0
	var down := false
	# (it may be well across the grove to the trees round its rim)
	for _i in 2600:
		await physics_frame
		if climber._tree:
			highest = maxf(highest, climber.global_position.y - base_y)
		if went and highest > 1.0 and climber.doing != Villager.Doing.CLIMB:
			# (let go, on its feet: free of the trunk, solid again)
			down = not climber.rig.climbing_npc and climber.collision_mask == 1
			break
	_check(went and highest > 1.5, "a kit climbs a tree (%.1f m up)" % highest)
	_check(down, "and comes down again to the ground (phase %d, doing %s)" % [climber._climb_phase, Villager.Doing.keys()[climber.doing]])

	# At play
	_only(band, kits)
	var played := {}
	for _i in 1800:
		await physics_frame
		for kit: Villager in kits:
			if kit.doing == Villager.Doing.PLAY:
				played[kit.play] = true
	_check(not played.is_empty(), "the kits play (%s)" % ", ".join(played.keys().map(func(k: int) -> String: return Villager.Play.keys()[k])))
	# Something brought home: they all celebrate, the giant clapping
	_only(band, band.members)
	player.global_position = (adults[0] as Villager).home + Vector3(0.0, 0.5, 3.0)
	Villagers.celebrate(player.global_position)
	var cheered := false
	var clapped := false
	var party := 0
	for _i in 60:
		await physics_frame
		party = 0
		for member: Villager in band.members:
			if member.doing == Villager.Doing.CELEBRATE:
				party += 1
				cheered = cheered or (not member.giant and member.rig._cheer_w > 0.6)
				clapped = clapped or (member.giant and member.rig._clap_w > 0.6)
	_check(party >= 3 and cheered, "they celebrate when something is brought home (%d)" % party)
	_check(clapped or not band.members.any(func(m: Villager) -> bool: return m.giant), "the giant claps")
	# Back in the grove with food found since he left it: they celebrate at the pile
	var zones := world.zones
	if zones and zones.grove >= 0:
		for _i in 240:
			await physics_frame
		var away_from := zones.grove + 1 if zones.grove + 1 < zones.names.size() else 0
		zones.current = away_from
		zones._crumbs_left_with = world.crumbs
		world.crumbs += 3
		player.global_position = zones.heart + Vector3(0.0, 0.5, 2.0)
		var glad := 0
		for _i in 20:
			await physics_frame
			glad = maxi(glad, band.members.filter(func(m: Villager) -> bool: return m.doing == Villager.Doing.CELEBRATE).size())
		_check(glad >= 3, "back in the grove with food, they celebrate (%d)" % glad)
	else:
		print("(no grove zone in this world: the food celebration not checked)")
	print("PASSED" if failures.is_empty() else "FAILED: " + ", ".join(failures))
	quit()


## Holds every raccoon of the band still but `these`.
func _only(band: Villagers, these: Array) -> void:
	for member in band.members:
		member.process_mode = Node.PROCESS_MODE_INHERIT if member in these else Node.PROCESS_MODE_DISABLED
