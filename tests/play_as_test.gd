extends SceneTree
## Playing as every animal (AnimalPlayer): in the grove each one is made, walks a little, runs, jumps (it leaves the
## ground and comes down), its tail button does its thing, and back to the raccoon at the end. No script errors.
## Headless:
##   godot --headless --path . --audio-driver Dummy --fixed-fps 60 -s res://tests/play_as_test.gd [-- fox frog ...]

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
	var only: Array = Array(OS.get_cmdline_user_args())
	for what: String in AnimalPlayer.ANIMALS:
		if not only.is_empty() and not what in only:
			continue
		BirdPlayer.play_as(world, StringName(what))
		for _i in 30:
			await physics_frame
		var animal := BirdPlayer.active(world) as AnimalPlayer
		if animal == null:
			_check(false, "%s is played" % what)
			continue
		# (each from the same open spot in the grove, where the raccoon was put away)
		animal.global_position = world.player.global_position + Vector3.UP * 0.2
		animal.velocity = Vector3.ZERO
		for _i in 20:
			await physics_frame
		var from := animal.global_position
		var settled := animal.is_on_floor() or animal._depth() > 0.0
		# Walk, then run, ahead (as far as the stick says: pressed held)
		Input.action_press(&"move_up", 0.4)
		for _i in 40:
			await physics_frame
		Input.action_press(&"move_up", 1.0)
		var fastest := 0.0
		for _i in 60:
			await physics_frame
			fastest = maxf(fastest, Vector2(animal.velocity.x, animal.velocity.z).length())
		Input.action_release(&"move_up")
		var went := Vector2(animal.global_position.x - from.x, animal.global_position.z - from.z).length()
		for _i in 20:
			await physics_frame
		# Jump
		var base := animal.global_position.y
		var top := base
		animal.press(&"jump", true)
		for _i in 50:
			await physics_frame
			top = maxf(top, animal.global_position.y)
		animal.press(&"jump", false)
		for _i in 30:
			await physics_frame
		animal.press(&"tail", true)
		for _i in 20:
			await physics_frame
		animal.press(&"tail", false)
		Input.action_press(&"move_up", 1.0)
		for _i in 10:
			await physics_frame
		Input.action_release(&"move_up")
		_check(settled and went > 0.6 and top > base + 0.1 and fastest > animal.walk_speed,
				"%s: stood, went %.1f m (fastest %.1f m/s), jumped %.2f m" % [what, went, fastest, top - base])
	if only.is_empty() or "climb" in only:
		await _climbing(world)
	BirdPlayer.play_as(world, &"raccoon")
	for _i in 10:
		await physics_frame
	_check(BirdPlayer.active(world) == null and world.player.visible, "back to the raccoon")
	print("PASSED" if failures.is_empty() else "FAILED: " + ", ".join(failures))
	quit()


## The climbers (the user, 2026-11-02: "add climbing for climbers"), in a yard of their own high over the grove: a
## squirrel up a trunk and over its top, up a thin pole; a cat up a drainpipe on to a roof; a fox (no climber) stays
## on the ground pushing at the trunk.
func _climbing(world: World) -> void:
	var at := world.player.global_position + Vector3.UP * 150.0
	var yard := Node3D.new()
	world.add_child(yard)
	yard.global_position = at
	_solid(yard, BoxShape3D.new(), Vector3(30.0, 0.2, 30.0), Vector3(0.0, -0.1, 0.0), false)
	var trunk := CylinderShape3D.new()
	trunk.radius = 0.35
	trunk.height = 5.0
	_solid(yard, trunk, Vector3.ZERO, Vector3(0.0, 2.5, 0.0), true)
	var pole := CylinderShape3D.new()
	pole.radius = 0.09
	pole.height = 4.0
	_solid(yard, pole, Vector3.ZERO, Vector3(6.0, 2.0, 0.0), true)
	# (a house: a wall 3 m high and its flat roof, not climbable; a drainpipe up its face that is)
	_solid(yard, BoxShape3D.new(), Vector3(4.0, 3.0, 4.0), Vector3(-6.0, 1.5, -2.0), false)
	var pipe := CylinderShape3D.new()
	pipe.radius = 0.06
	pipe.height = 3.0
	_solid(yard, pipe, Vector3.ZERO, Vector3(-6.0, 1.5, 0.07), true)
	for _i in 5:
		await physics_frame
	var trunk_top := await _climb_one(world, "squirrel", at, at + Vector3(0.0, 0.0, 1.6), at + Vector3(0.0, 2.5, 0.0))
	_check(trunk_top > at.y + 4.9, "a squirrel climbs a trunk and over its top (%.1f m up)" % (trunk_top - at.y))
	var pole_top := await _climb_one(world, "squirrel", at, at + Vector3(6.0, 0.0, 1.6), at + Vector3(6.0, 2.0, 0.0))
	_check(pole_top > at.y + 3.0, "a squirrel climbs a pole (%.1f m up)" % (pole_top - at.y))
	var roof := await _climb_one(world, "cat_1", at, at + Vector3(-6.0, 0.0, 1.8), at + Vector3(-6.0, 1.5, 0.07), true)
	_check(roof > at.y + 2.9, "a cat climbs a drainpipe on to the roof (%.1f m up)" % (roof - at.y))
	var stays := await _climb_one(world, "fox", at, at + Vector3(0.0, 0.0, 1.6), at + Vector3(0.0, 2.5, 0.0))
	_check(stays < at.y + 1.2, "a fox does not climb (%.1f m up)" % (stays - at.y))
	yard.queue_free()


## Plays `what` from `start` facing `target`, the stick held up the screen: the highest it gets on its feet or climbing.
## With `on_top`, the height it ends standing at.
func _climb_one(world: World, what: String, _at: Vector3, start: Vector3, target: Vector3, on_top := false) -> float:
	BirdPlayer.play_as(world, StringName(what))
	for _i in 5:
		await physics_frame
	var animal := BirdPlayer.active(world) as AnimalPlayer
	animal.global_position = start + Vector3.UP * 0.1
	animal.velocity = Vector3.ZERO
	var way := Vector3(target.x - start.x, 0.0, target.z - start.z).normalized()
	animal.facing_yaw = atan2(way.x, way.z)
	for _i in 5:
		await physics_frame
	animal.camera.look_along(way)
	var top := animal.global_position.y
	var climbed := false
	var after := 0
	for _i in 420:
		Input.action_press(&"move_up", 1.0)
		await physics_frame
		climbed = climbed or animal.climbing
		top = maxf(top, animal.global_position.y)
		# (over the top and on its feet a moment: let go, so it does not run off the far side)
		after = after + 1 if climbed and not animal.climbing and animal.is_on_floor() else 0
		if after > 6:
			break
	Input.action_release(&"move_up")
	for _i in 30:
		await physics_frame
	print("  %s: climbed %s, top %.2f, ends at %.2f, on the floor %s" % [what, climbed, top - start.y, animal.global_position.y - start.y, animal.is_on_floor()])
	return animal.global_position.y if on_top else top


func _solid(parent: Node3D, shape: Shape3D, size: Vector3, place: Vector3, climbable: bool) -> void:
	if shape is BoxShape3D:
		(shape as BoxShape3D).size = size
	var body := StaticBody3D.new()
	var collider := CollisionShape3D.new()
	collider.shape = shape
	body.add_child(collider)
	body.position = place
	if climbable:
		body.add_to_group(&"climbable")
	parent.add_child(body)
