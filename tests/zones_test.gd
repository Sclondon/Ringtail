extends SceneTree
## The zones (Zones): four sides (markers of the test's own if the world has none) and the grove, five: every Crumb
## counted in one, the HUD's zone following him, and a Crumb taken in a zone counted there. Headless:
##   godot --headless --path . --audio-driver Dummy --fixed-fps 60 -s res://tests/zones_test.gd

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
	for _i in 20:
		await physics_frame
	var heart: Vector3 = world.markers.get("haven", world.markers.get("grove_heart", Transform3D())).origin
	# (unless the world has its own zones already)
	var zones := world.zones
	if zones == null or zones.names.is_empty():
		for k in 4:
			var a := TAU * k / 4.0
			world.markers["zone_%d_Side%d" % [k, k]] = Transform3D(Basis.IDENTITY, heart + Vector3(cos(a), 0.0, sin(a)) * 40.0)
		zones.queue_free()
		zones = Zones.place(world)
		world.zones = zones
	_check(zones.names.size() == 5 and zones.names[zones.grove] == "Grove", "five zones (%s)" % ", ".join(zones.names))
	_check(zones.zone_of(heart) == zones.grove and zones.zone_of(heart + Vector3(Zones.GROVE_RADIUS + 5.0, 0.0, 0.0)) != zones.grove, "the grove is the zone round its heart")
	var outside := 0
	for node in world.get_children():
		if node is Pickup and (node as Pickup).kind == Pickup.Kind.CRUMB:
			outside += 1
	var cans := 0
	for node in world.get_children():
		if node is TrashCan:
			cans += (node as TrashCan).holds
	var counted := 0
	for k in zones.names.size():
		counted += zones.food_total[k]
	_check(counted == outside + cans and counted > 0, "every Crumb is in a zone (%d)" % counted)
	# A Crumb in a zone: he goes there, and takes it
	var crumb: Pickup
	for node in world.get_children():
		if node is Pickup and (node as Pickup).kind == Pickup.Kind.CRUMB and zones.zone_of((node as Pickup).global_position) >= 0:
			crumb = node
			break
	var zone := zones.zone_of(crumb.global_position)
	world.player.global_position = crumb.global_position + Vector3(0.0, 0.5, 2.0)
	for _i in 5:
		await physics_frame
	_check(zones.current == zone, "he is in its zone (%s)" % zones.names[zone])
	var before: int = zones.food[zone]
	crumb.take()
	await physics_frame
	_check(zones.food[zone] == before + 1, "taken, it counts in that zone")
	print("PASSED" if failures.is_empty() else "FAILED: " + ", ".join(failures))
	quit()
