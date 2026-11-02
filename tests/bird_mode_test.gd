extends SceneTree
## Playing as a bird (BirdPlayer): as the crow he flaps up, glides, settles on a wire, lands on a roof and takes a
## Crumb; as the owl he glides slower; back to the raccoon, on the ground under the bird. Prints PASSED or FAILED.
## Headless:
##   godot --headless --path . --audio-driver Dummy --fixed-fps 60 -s res://tests/bird_mode_test.gd

var failures: Array[String] = []
var world: World


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


func _run() -> void:
	await _frames(20)
	var start := world.player.global_position
	BirdPlayer.play_as(world, &"crow")
	await _frames(5)
	var crow := BirdPlayer.active(world)
	_check(crow != null and crow.kind == &"crow" and not world.player.visible and crow.camera.is_current(), "playing as the crow: he is put away, its camera on")

	# Flapping up
	var low := crow.global_position.y
	for _k in 8:
		crow.press(&"jump", true)
		await _frames(2)
		crow.press(&"jump", false)
		await _frames(12)
	var climbed := crow.global_position.y - low
	_check(climbed > 2.0, "flaps take it up (%.1f m)" % climbed)
	# Gliding: jump held on the way down (measured once it is coming down)
	crow.press(&"jump", true)
	for _i in 400:
		await physics_frame
		if crow.velocity.y < -0.3:
			break
	await _frames(40)
	var falling := crow.velocity.y
	crow.press(&"jump", false)
	_check(crow.flying and falling > -float(BirdPlayer.KINDS[&"crow"].glide_fall) - 0.2, "held, it glides down slowly (%.2f m/s)" % falling)

	# Settling on a wire: near one, scurry, and it makes for it and sits on it
	var wire: Tightrope
	for node in get_nodes_in_group(&"tightropes"):
		if (node as Tightrope).span() > 5.0:
			wire = node
			break
	var spot := wire.point_at_distance(wire.span() * 0.5)
	crow.global_position = spot + Vector3(0.6, 1.5, 0.0)
	crow.velocity = Vector3.ZERO
	await _frames(2)
	crow.press(&"scurry", true)
	await _frames(1)
	crow.press(&"scurry", false)
	await _frames(90)
	# (whichever wire is nearest it: the power lines above the phone line are wires too)
	var off_wire := func() -> float:
		var least := INF
		for node in get_nodes_in_group(&"tightropes"):
			least = minf(least, (node as Tightrope).distance_to(crow.global_position))
		return least
	var on_wire: bool = off_wire.call() < 0.35
	await _frames(60)
	_check(on_wire and off_wire.call() < 0.35 and not crow.flying, "settles on a wire, and stays (%.2f m off it)" % off_wire.call())

	# Landing on a roof: dropped over one, it comes down on it
	var roof := _find_roof(start)
	_check(roof != Vector3.INF, "a roof to land on")
	if roof != Vector3.INF:
		crow.global_position = roof + Vector3.UP * 2.0
		crow.velocity = Vector3.ZERO
		crow.settle_on = Vector3.INF
		await _frames(120)
		_check(crow.is_on_floor() and absf(crow.global_position.y - roof.y) < 0.4, "lands on a roof (%.2f m off it)" % (crow.global_position.y - roof.y))

	# Taking a Crumb
	var crumb: Pickup
	for node in world.get_children():
		if node is Pickup and (node as Pickup).kind == Pickup.Kind.CRUMB:
			crumb = node
			break
	var had := world.crumbs
	crow.global_position = crumb.global_position + Vector3.UP * 0.1
	crow.velocity = Vector3.ZERO
	await _frames(10)
	_check(world.crumbs == had + 1, "the crow takes a Crumb for him")

	# The owl: slower down, gliding
	BirdPlayer.play_as(world, &"owl")
	await _frames(5)
	var owl := BirdPlayer.active(world)
	_check(owl != null and owl.kind == &"owl", "playing as the owl")
	owl.global_position += Vector3.UP * 8.0
	owl.press(&"jump", true)
	await _frames(1)
	await _frames(90)
	var owl_fall := owl.velocity.y
	owl.press(&"jump", false)
	_check(owl_fall > -float(BirdPlayer.KINDS[&"owl"].glide_fall) - 0.2 and owl_fall > falling - 0.05, "the owl glides slower still (%.2f m/s)" % owl_fall)

	# Back to the raccoon: on the ground under the bird
	var under := owl.global_position
	BirdPlayer.play_as(world, &"raccoon")
	await _frames(30)
	var him := world.player
	_check(BirdPlayer.active(world) == null and him.visible and him.process_mode == Node.PROCESS_MODE_INHERIT and world.camera.is_current(), "back to the raccoon, his camera on")
	_check(Vector2(him.global_position.x - under.x, him.global_position.z - under.z).length() < 1.0 and him.global_position.y < under.y, "he comes back on the ground under the bird")
	print("PASSED" if failures.is_empty() else "FAILED: " + ", ".join(failures))
	quit()


## A roof near `near`: a high level face found straight down from above.
func _find_roof(near: Vector3) -> Vector3:
	var space := world.get_world_3d().direct_space_state
	for ring in range(4, 60, 3):
		for k in 24:
			var a := TAU * k / 24.0
			var at := near + Vector3(cos(a), 0.0, sin(a)) * ring
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(at + Vector3.UP * 60.0, at + Vector3.DOWN * 60.0, 1))
			if hit.is_empty() or not hit.collider is StaticBody3D:
				continue
			var below := space.intersect_ray(PhysicsRayQueryParameters3D.create((hit.position as Vector3) + Vector3.DOWN * 0.3, (hit.position as Vector3) + Vector3.DOWN * 60.0, 1))
			if (hit.normal as Vector3).y > 0.55 and not below.is_empty() and (hit.position as Vector3).y - (below.position as Vector3).y > 3.0:
				return hit.position
	return Vector3.INF
