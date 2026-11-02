extends SceneTree
## The town's traffic (HazardCar): every vehicle gets up to speed on its road (each kind past 70% of its cruise: they
## climb slower), none goes into a sharp bend faster than the bend allows, no two on the same road ever run into each other, and on the hill every wheel stays on the road
## (within 5 cm of it, crests and hairpins too). Headless, about 25 s of play:
##   godot --headless --path . --audio-driver Dummy --fixed-fps 60 -s res://tests/vehicle_test.gd

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
	for _i in 10:
		await physics_frame
	# (every road running: not only his zone's (ZoneStreaming), and by day (DayNight puts fewer out at night))
	for node in world.find_children("*", "ZoneStreaming", true, false):
		node.queue_free()
	if DayNight.current:
		DayNight.current.set_hour(12.0)
		DayNight.current.held = true
	await physics_frame
	for node in get_nodes_in_group(&"cars"):
		(node as Node).process_mode = Node.PROCESS_MODE_INHERIT
		(node as Node3D).visible = true
	# (him out of the way, off the roads)
	world.player.process_mode = Node.PROCESS_MODE_DISABLED
	world.player.global_position = Vector3(0.0, -200.0, 0.0)
	var cars: Array[HazardCar] = []
	for node in get_nodes_in_group(&"cars"):
		cars.append(node as HazardCar)
	var kinds := {}
	for car in cars:
		kinds[car.kind] = kinds.get(car.kind, 0) + 1
	_check(cars.size() >= 3 and kinds.size() >= 3, "%d vehicles of %d kinds %s" % [cars.size(), kinds.size(), kinds])
	var fastest := {}
	var closest := INF
	var worst := 0.0
	var over := 0.0
	var over_kind := ""
	var worst_kind := ""
	for _f in 1500:
		await physics_frame
		for car in cars:
			fastest[car] = maxf(fastest.get(car, 0.0), car.speed)
			if car.bend_sharp > 0.5 and car.speed - car.bend_speed > over:
				over = car.speed - car.bend_speed
				over_kind = "%s at %.1f m/s" % [car.kind, car.speed]
			if car.contact_error > worst:
				worst = car.contact_error
				worst_kind = "%s on road %d" % [car.kind, car.road]
			for other in cars:
				if other == car or other.road != car.road:
					continue
				var gap := fposmod(other.along - car.along, car.loop_length()) - car.half_size.z - other.half_size.z
				closest = minf(closest, gap)
	# (each kind: its fastest one past 70% of its cruising speed; one stuck behind a bus up a hill may not)
	var best := {}
	for car in cars:
		best[car.kind] = maxf(best.get(car.kind, 0.0), fastest[car])
	var slow: Array[String] = []
	for kind: StringName in best:
		if best[kind] < 0.7 * float(HazardCar.KINDS[kind]["cruise"]):
			slow.append("%s %.1f" % [kind, best[kind]])
	_check(slow.is_empty(), "every one gets up to speed%s" % ("" if slow.is_empty() else " (slow: %s)" % ", ".join(slow)))
	_check(closest > 0.5, "none runs into the one ahead (closest %.2f m bumper to bumper)" % closest)
	_check(over < 1.0, "none overshoots a sharp bend (worst %.2f m/s over its speed%s)" % [over, "" if over_kind.is_empty() else ", " + over_kind])
	var tops := {}
	for car in cars:
		tops[car.kind] = maxf(tops.get(car.kind, 0.0), fastest[car])
	print("top speeds (m/s): ", tops)
	_check(worst < 0.05, "every wheel on the road, hill and hairpins too (worst %.3f m, %s)" % [worst, worst_kind])
	# One stopped, and another right behind it at speed: it pulls up short
	var behind: HazardCar
	var front: HazardCar
	for car in cars:
		for other in cars:
			if other != car and other.road == car.road and behind == null:
				behind = car
				front = other
	front._stop_left = 6.0
	# (as far back as it needs to brake from its cruise, and 4 m more: at 20 m/s that is some way)
	var room := behind.cruise * behind.cruise / (2.0 * HazardCar.BRAKE * 0.7) + HazardCar.GAP + 4.0
	behind.along = fposmod(front.along - front.half_size.z - behind.half_size.z - room, behind.loop_length())
	behind.speed = behind.cruise
	var tightest := INF
	for _f in 300:
		await physics_frame
		tightest = minf(tightest, fposmod(front.along - behind.along, behind.loop_length()) - front.half_size.z - behind.half_size.z)
	_check(tightest > 0.5 and behind.speed < 0.5, "pulls up behind one stopped (%.2f m short of it)" % tightest)
	print("PASSED" if failures.is_empty() else "FAILED: " + ", ".join(failures))
	quit()
