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
	BirdPlayer.play_as(world, &"raccoon")
	for _i in 10:
		await physics_frame
	_check(BirdPlayer.active(world) == null and world.player.visible, "back to the raccoon")
	print("PASSED" if failures.is_empty() else "FAILED: " + ", ".join(failures))
	quit()
