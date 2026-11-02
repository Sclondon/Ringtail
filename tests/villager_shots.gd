extends SceneTree
## Pictures of the other raccoons (Villagers): the grove's gathering from four sides and above, a kit beside a
## grown-up close up from four sides, its speech bubble, and a raccoon out in the town.
##   godot --path . --audio-driver Dummy --fixed-fps 60 --resolution 1280x720 -s res://tests/villager_shots.gd -- --out=<dir>
## Needs a window (kept off the screen).

var out := "user://villager_shots"
var world: World
var eye: Camera3D


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.substr(6)
	DirAccess.make_dir_recursive_absolute(out)
	root.position = Vector2i(-3000, 0)
	world = (load("res://scenes/world1.tscn") as PackedScene).instantiate()
	root.add_child(world)
	_run.call_deferred()


func _frames(count: int) -> void:
	for _i in count:
		await process_frame


func _shot(name: String) -> void:
	await _frames(3)
	root.get_texture().get_image().save_png(out.path_join(name + ".png"))
	print("SHOT ", name)


func _look(from: Vector3, at: Vector3, fov := 50.0) -> void:
	eye.fov = fov
	eye.global_position = from
	eye.look_at(at)
	eye.make_current()


func _run() -> void:
	await _frames(30)
	var band := world.get_node(^"Villagers") as Villagers
	eye = Camera3D.new()
	world.add_child(eye)
	var grove: Array[Villager] = []
	for member in band.members:
		if member.home != Vector3.INF:
			grove.append(member)
	var heart: Vector3 = grove[3].home
	# (the hero out of the way, but near enough that they are awake)
	world.player.global_position = heart + Vector3(0.0, 0.5, 6.0)
	await _frames(240)
	for member in band.members:
		print("%s kit %s at %s doing %s" % [member.name, member.kit, member.global_position, Villager.Doing.keys()[member.doing]])
	for k in 4:
		var a := TAU * k / 4.0
		_look(heart + Vector3(sin(a) * 6.0, 2.4, cos(a) * 6.0), heart + Vector3.UP * 0.3)
		await _frames(50)
		await _shot("grove_%d" % k)
	_look(heart + Vector3(0.0, 7.0, 0.5), heart)
	await _shot("grove_above")

	# A kit and a grown-up side by side, stood still, close up from four sides
	var adult := grove[0]
	var kit := grove[3]
	for member in band.members:
		member.visible = member == adult or member == kit
	for node in get_nodes_in_group(&"hazards"):
		node.process_mode = Node.PROCESS_MODE_DISABLED
	world.get_node(^"Squad").visible = false
	for member in [adult, kit]:
		member.process_mode = Node.PROCESS_MODE_DISABLED
		member.rig.process_mode = Node.PROCESS_MODE_ALWAYS
	adult.global_position = heart + Vector3(-0.35, 0.0, 0.0)
	kit.global_position = heart + Vector3(0.35, 0.0, 0.0)
	adult.rotation.y = 0.0
	kit.rotation.y = 0.0
	await _frames(30)
	for k in 4:
		var a := TAU * k / 4.0
		_look(heart + Vector3(sin(a) * 2.2, 0.7, cos(a) * 2.2), heart + Vector3.UP * 0.35, 40.0)
		await _frames(10)
		await _shot("pair_%d" % k)
	for member in band.members:
		member.visible = true
	world.get_node(^"Squad").visible = true
	for member in [adult, kit]:
		member.process_mode = Node.PROCESS_MODE_INHERIT

	# Up to one and talking
	world.camera.make_current()
	var talker := grove[1]
	world.player.global_position = talker.global_position + Vector3(0.0, 0.3, 1.3)
	world.player.velocity = Vector3.ZERO
	world.camera.snap()
	await _frames(40)
	# (near one, it says its line in a bubble over its head: Chatter)
	await _frames(60)
	await _shot("talk_bubble")

	# Out in the town
	var goer: Villager = null
	for member in band.members:
		if not member.route.is_empty():
			goer = member
			break
	world.player.global_position = goer.global_position + Vector3(0.0, 0.5, 5.0)
	await _frames(120)
	_look(goer.global_position + Vector3(3.0, 2.0, 3.0), goer.global_position + Vector3.UP * 0.3)
	await _shot("town")
	print("SHOTS DONE ", out)
	quit()
