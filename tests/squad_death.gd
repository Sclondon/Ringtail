extends SceneTree
## A squad raccoon killed (dropped from a height) goes limp and stays; the rest close up; none is put back by the
## hero when far. Headless:
##   godot --headless --path . --audio-driver Dummy --fixed-fps 60 -s res://tests/squad_death.gd

var world: World


func _initialize() -> void:
	world = (load("res://scenes/world1.tscn") as PackedScene).instantiate()
	root.add_child(world)
	_run.call_deferred()


func _run() -> void:
	for _i in 30:
		await physics_frame
	var squad := world.get_node(^"Squad") as Squad
	var count := squad.members.size()
	var one := squad.members[0]
	one.global_position += Vector3.UP * 30.0
	for _i in 180:
		await physics_frame
	var lying := one.rig.limp_position()
	for _i in 60:
		await physics_frame
	var still := one.rig.limp_position().distance_to(lying) < 0.05
	var ok := one.dead and one.rig.is_limp() and squad.members.size() == count - 1 and still
	print("dead %s limp %s band %d->%d still %s" % [one.dead, one.rig.is_limp(), count, squad.members.size(), still])
	# Far off: it is not put back next to him
	var two := squad.members[0]
	two.global_position = world.player.global_position + Vector3(30.0, 2.0, 0.0)
	await physics_frame
	await physics_frame
	var stays := two.global_position.distance_to(world.player.global_position) > 20.0
	print("far one not teleported: %s" % stays)
	print("PASSED" if ok and stays else "FAILED")
	quit()
