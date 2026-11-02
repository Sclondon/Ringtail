extends SceneTree
## Loads World 1 and puts the raccoon through his moves and the world through its
## goals; prints PASSED or FAILED (and each check as it goes). Headless:
##   godot --headless --path . --audio-driver Dummy --fixed-fps 60 -s res://tests/smoke.gd

var world: World
var failures: Array[String] = []


func _initialize() -> void:
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


func _release() -> void:
	for action: StringName in [&"move_up", &"move_down", &"duck", &"sprint", &"jump", &"tail"]:
		Input.action_release(action)


func _put(at: Vector3) -> void:
	_release()
	world.player.global_position = at
	world.player.velocity = Vector3.ZERO
	await _frames(20)


func _run() -> void:
	await _frames(10)
	var player := world.player
	var rig := player.get_node(^"Rig") as RaccoonRig
	var moves := player.get_node(^"TailMoves") as TailMoves
	_check(world.crumbs_total >= 90, "world has its Crumbs (%d)" % world.crumbs_total)
	_check(get_nodes_in_group(&"cats").size() >= 3, "cats about the town")
	_check(get_nodes_in_group(&"hazards").size() >= 6, "hazards about the town (%d)" % get_nodes_in_group(&"hazards").size())
	var band := world.find_children("*", "", true, false).filter(func(n: Node) -> bool: return n is SquadRaccoon)
	_check(band.size() >= 3, "his band of raccoons (%d)" % band.size())
	# (out of the way of the checks below: the hazards and the band stood still and put far off)
	var quiet: Array = band.duplicate()
	for node in get_nodes_in_group(&"hazards"):
		quiet.append(node)
		if node.get_parent() is HazardCrows:
			quiet.append(node.get_parent())
	for node: Node in quiet:
		node.process_mode = Node.PROCESS_MODE_DISABLED
		if node is Node3D:
			(node as Node3D).global_position.y = -300.0

	# Running goes onto all fours, bounding
	await _put(Vector3(0.0, 0.15, 29.5))
	Input.action_press(&"move_up")
	var most := 0.0
	var bound := 0.0
	for _i in 70:
		await physics_frame
		most = maxf(most, rig._quad)
		bound = maxf(bound, rig._gallop)
	_check(most > 0.9 and bound > 0.5, "running on all fours (quad %.2f)" % most)

	# Scurrying, he goes on all fours at a walk too
	await _put(Vector3(0.0, 0.15, 29.5))
	(player.get_node(^"Scurry") as Scurry).button = true
	await _frames(10)
	Input.action_press(&"move_up", 0.35)
	await _frames(50)
	_check(rig._quad > 0.9 and rig._gallop < 0.2, "scurrying on all fours at a walk (quad %.2f)" % rig._quad)
	(player.get_node(^"Scurry") as Scurry).button = false

	# Jump pressed again in the air and held: the twirl, falling slowly
	await _put(Vector3(0.0, 0.15, 29.5))
	Input.action_press(&"jump")
	player._queue_jump()
	var glided := false
	var slowest := 0.0
	for _i in 60:
		await physics_frame
		if _i == 15:
			player._queue_jump()
		if moves.gliding:
			glided = true
			slowest = minf(slowest, player.velocity.y)
	_check(glided and slowest > -moves.glide_fall - 0.6, "twirl slows the fall (%.2f m/s)" % slowest)

	# A tail spin on the ground beats a cat beside him
	var cat := get_nodes_in_group(&"cats")[0] as YardCat
	cat.set_physics_process(false)
	# (behind it along the way he faces, so it is in front of him)
	var ahead := Vector3(sin(player.facing_yaw), 0.0, cos(player.facing_yaw))
	await _put(cat.global_position - ahead)
	ahead = Vector3(sin(player.facing_yaw), 0.0, cos(player.facing_yaw))
	player.global_position = cat.global_position - ahead
	await _frames(2)
	moves.press()
	await _frames(20)
	_check(cat.mode == YardCat.Mode.DAZED, "tail spin on the ground beats a cat")
	cat.set_physics_process(true)

	# The long jump: flat out, duck into a slide and jump, and he goes long
	await _put(Vector3(0.0, 0.15, -29.5))
	Input.action_press(&"move_up")
	await _frames(45)
	Input.action_press(&"duck")
	await _frames(3)
	var took_off := player.global_position
	player._queue_jump()
	Input.action_press(&"jump")
	var long_speed := 0.0
	for _i in 12:
		await physics_frame
		long_speed = maxf(long_speed, Vector2(player.velocity.x, player.velocity.z).length())
	_release()
	await _frames(50)
	_check(long_speed > 8.0, "a long jump out of a slide (%.1f m/s along)" % long_speed)

	# The spin in the air is a second jump
	await _put(Vector3(0.0, 0.15, 29.5))
	Input.action_press(&"jump")
	player._queue_jump()
	await _frames(16)
	var before_spin := player.velocity.y
	moves.press()
	await _frames(2)
	_check(player.velocity.y > 5.0 and before_spin < 3.0, "the air spin is a second jump (%.1f m/s up)" % player.velocity.y)
	Input.action_release(&"jump")
	await _frames(60)

	# A spin in the air
	await _put(Vector3(0.0, 0.15, 29.5))
	player._queue_jump()
	await _frames(12)
	moves.press()
	await _frames(3)
	_check(moves.spin < 1.0, "tail spin in the air")

	# Crumbs are taken by running into them
	var before := world.crumbs
	var crumb: Pickup
	for node in get_nodes_in_group(&"pickups"):
		if (node as Pickup).kind == Pickup.Kind.CRUMB:
			crumb = node
			break
	await _put(crumb.global_position)
	await _frames(5)
	_check(world.crumbs > before, "a Crumb taken")

	# Beating the other cats brings out their Bottlecap
	for other in get_nodes_in_group(&"cats"):
		if other != cat:
			(other as YardCat).tail_hit(Vector3.ZERO, Vector3.UP)
	await _frames(5)
	_check(_cap_out("cats"), "beating every cat brings out a Bottlecap")

	# The race: every race crumb in time brings out its Bottlecap
	world.race.start()
	await _frames(2)
	for node in get_nodes_in_group(&"pickups"):
		if (node as Pickup).kind == Pickup.Kind.RACE:
			(node as Pickup).take()
	await _frames(5)
	_check(_cap_out("race"), "winning the race brings out a Bottlecap")

	# Taking a Bottlecap counts it
	for node in get_nodes_in_group(&"pickups"):
		if (node as Pickup).kind == Pickup.Kind.CAP and (node as Pickup).tag == "roof":
			(node as Pickup).take()
	await _frames(5)
	_check(world.caps.has("roof"), "a Bottlecap taken")

	# Dropped onto a wire (GameCommon's Tightrope, Warren's) he lands on it and walks it; duck and he hangs under it
	var wire: Tightrope
	for node in world.get_children():
		if node is Tightrope:
			wire = node
			break
	_check(wire != null, "the world has wires")
	if wire:
		_release()
		player.global_position = wire.point_at_distance(wire.span() * 0.5) + Vector3.UP * 1.0
		player.velocity = Vector3.ZERO
		wire.bodies_now()
		await _frames(60)
		# (whichever wire he comes down on: the power lines above the phone line are wires too, and sag near it)
		var on_one := false
		for node in world.get_children():
			if node is Tightrope and (node as Tightrope).distance_to(player.global_position) < 0.3:
				on_one = true
		_check(player.tightrope > 0.0 and on_one, "lands on a wire and walks it")
		Input.action_press(&"duck")
		await _frames(4)
		Input.action_release(&"duck")
		await _frames(20)
		_check(player.state == Player.State.HANG, "ducks to hang under a wire")
		Input.action_press(&"duck")
		await _frames(4)
		Input.action_release(&"duck")
		await _frames(30)

	# Swimming, a jump is a big leap out of the water
	var pond: Pool = null
	for node in world.get_children():
		if node is Pool:
			pond = node
	if pond:
		await _put(pond.global_position + Vector3.DOWN * 0.6)
		await _frames(60)
		var swimming := player.state == Player.State.SWIM
		Input.action_press(&"jump")
		player._queue_jump()
		var highest := -INF
		for _i in 50:
			await physics_frame
			highest = maxf(highest, player.global_position.y)
		Input.action_release(&"jump")
		_check(swimming and highest - pond.surface_y() > 1.7, "a leap out of the water (%.2f m over it)" % (highest - pond.surface_y()))

	# Whipping the stick round he spins; jumping then is a spin jump, higher than a jump
	await _put(Vector3(0.0, 0.15, 29.5))
	var spinner := player.get_node(^"SpinJump") as SpinJump
	player.is_spinning = true
	player._queue_jump()
	Input.action_press(&"jump")
	var spin_top := player.global_position.y
	var twirled := false
	for _i in 60:
		await physics_frame
		spin_top = maxf(spin_top, player.global_position.y)
		twirled = twirled or spinner.twirling
	_release()
	_check(twirled and spin_top - 0.05 > player.jump_height * 1.3, "a spin jump goes higher (%.2f m)" % (spin_top - 0.05))
	await _frames(90)

	# Scurrying into a power pole, he climbs it
	var scurry := player.get_node(^"Scurry") as Scurry
	await _put(Vector3(34.4, 0.15, -1.2))
	world.camera.set_process(false)
	world.camera.set_physics_process(false)
	world.camera.global_transform = Transform3D(Basis(Vector3.UP, PI), Vector3(34.4, 2.0, -5.0))
	scurry.button = true
	Input.action_press(&"move_up")
	var base := player.global_position.y
	var was_climbing := false
	for _i in 120:
		await physics_frame
		was_climbing = was_climbing or scurry.climbing
	_check(was_climbing and player.global_position.y - base > 2.5, "scurries up a pole (%.1f m)" % (player.global_position.y - base))
	scurry.button = false
	_release()
	world.camera.set_process(true)
	world.camera.set_physics_process(true)

	# A pounce hurts, and losing every heart sends him back
	world.hurt(player.global_position + Vector3.FORWARD)
	_check(world.hearts == World.MAX_HEARTS - 1, "hurt takes a heart")
	_release()

	# The other raccoons: grown-ups and kits at the grove, some out in the town; one can be talked to
	var villagers := world.get_node(^"Villagers") as Villagers
	var at_grove := villagers.members.filter(func(m: Villager) -> bool: return m.home != Vector3.INF)
	var kits := at_grove.filter(func(m: Villager) -> bool: return m.kit)
	var out_about := villagers.members.filter(func(m: Villager) -> bool: return not m.route.is_empty())
	_check(at_grove.size() >= 6 and kits.size() >= 3 and out_about.size() >= 3, "raccoons at the grove (%d, %d kits) and about the town (%d)" % [at_grove.size(), kits.size(), out_about.size()])
	var talker: Villager = at_grove[0]
	await _put(talker.global_position + Vector3(0.0, 0.4, 1.0))
	await _frames(30)
	# (whichever is nearest him talks: a kit may have run up closer)
	var open := func() -> Array: return villagers.talk._bubbles.values().filter(func(b: SpeechBubble) -> bool: return b.openness > 0.5)
	var said: bool = (open.call() as Array).size() == 1
	await _put(talker.global_position + Vector3(0.0, 0.4, 12.0))
	await _frames(40)
	_check(said and (open.call() as Array).is_empty() and not Player.input_blocked, "a raccoon at the grove says its line in a bubble as he comes near, and stops as he goes")
	# (killed, one goes limp where it is and stays: it is never put back)
	var goner: Villager = out_about[0]
	goner.global_position.y = World.KILL_Y - 5.0
	await _frames(5)
	_check(goner.dead and goner.global_position.y < World.KILL_Y, "a raccoon off the world is dead, not put back")
	print("PASSED" if failures.is_empty() else "FAILED: " + ", ".join(failures))
	quit(0 if failures.is_empty() else 1)


func _cap_out(called: String) -> bool:
	for node in get_nodes_in_group(&"pickups"):
		if (node as Pickup).kind == Pickup.Kind.CAP and (node as Pickup).tag == called:
			return true
	return false
