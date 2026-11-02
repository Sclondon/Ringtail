extends SceneTree
## The town's traffic (HazardCar): every vehicle gets up to speed on its road (a car past 8 m/s, a bus past 5) and no
## two on the same road ever run into each other. Headless, about 25 s of play:
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
	for _f in 1500:
		await physics_frame
		for car in cars:
			fastest[car] = maxf(fastest.get(car, 0.0), car.speed)
			for other in cars:
				if other == car or other.road != car.road:
					continue
				var gap := fposmod(other.along - car.along, car.loop_length()) - car.half_size.z - other.half_size.z
				closest = minf(closest, gap)
	var slow: Array[String] = []
	for car in cars:
		if fastest[car] < (5.0 if car.kind == &"bus" else 8.0):
			slow.append("%s %.1f" % [car.kind, fastest[car]])
	_check(slow.is_empty(), "every one gets up to speed%s" % ("" if slow.is_empty() else " (slow: %s)" % ", ".join(slow)))
	_check(closest > 0.5, "none runs into the one ahead (closest %.2f m bumper to bumper)" % closest)
	# One stopped, and another right behind it at speed: it pulls up short
	var behind: HazardCar
	var front: HazardCar
	for car in cars:
		for other in cars:
			if other != car and other.road == car.road and behind == null:
				behind = car
				front = other
	front._stop_left = 6.0
	behind.along = fposmod(front.along - front.half_size.z - behind.half_size.z - 8.0, behind.loop_length())
	behind.speed = behind.cruise
	var tightest := INF
	for _f in 240:
		await physics_frame
		tightest = minf(tightest, fposmod(front.along - behind.along, behind.loop_length()) - front.half_size.z - behind.half_size.z)
	_check(tightest > 0.5 and behind.speed < 0.5, "pulls up behind one stopped (%.2f m short of it)" % tightest)
	print("PASSED" if failures.is_empty() else "FAILED: " + ", ".join(failures))
	quit()
