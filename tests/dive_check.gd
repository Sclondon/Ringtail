extends SceneTree
## Runs, jumps, presses duck in the air: does he dive? Prints what blocks it frame by frame. Headless:
##   godot --headless --path . --audio-driver Dummy --fixed-fps 60 -s res://tests/dive_check.gd

var world: World


func _initialize() -> void:
	world = (load("res://scenes/world1.tscn") as PackedScene).instantiate()
	root.add_child(world)
	_run.call_deferred()


func _run() -> void:
	for _i in 10:
		await physics_frame
	var player := world.player
	player.global_position = Vector3(0.0, 0.15, 29.5)
	Input.action_press(&"move_up")
	for _i in 60:
		await physics_frame
	print("speed %.2f sprinting %s" % [Vector2(player.velocity.x, player.velocity.z).length(), player.is_sprinting])
	Input.action_press(&"jump")
	player._queue_jump()
	for _i in 12:
		if _i == 3:
			Input.action_release(&"jump")
		await physics_frame
		print("after jump: floor %s vy %.2f buffer %.2f jumping %s state %s twirl %s" % [player.is_on_floor(), player.velocity.y, player._jump_buffer, player._jumping, player.state, (player.get_node(^"SpinJump") as SpinJump).twirling])
	Input.action_press(&"duck")
	var dived := false
	for _i in 30:
		await physics_frame
		dived = dived or player.is_diving
		print("air %s jumping %s state %s duck %s spinning %s" % [not player.is_on_floor(), player._jumping, player.state, player.is_ducking, player.is_spinning])
	print("DIVED" if dived else "NO DIVE")
	quit()
