extends SceneTree
## Pictures of the four-sided hill (tools/build_town.py): the start in the clearing (the wood round it), the pond
## from its jetty, the view from the grove and from down a street (the painted hills, their trees, the volcano), a
## street's markings with the pixel filter as set and with it off, the ring road. Window needed (kept off screen):
##   godot --path . --audio-driver Dummy --fixed-fps 60 --resolution 1280x720 -s res://tests/zone_shots.gd -- --out=<dir>

var out := "user://zone_shots"
var world: World


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


## (a pad elsewhere can press Start on this window: the pause screen is shut before each picture)
func _unpause() -> void:
	for node in root.find_children("*", "PauseMenu", true, false):
		if node.has_method(&"is_open") and node.is_open():
			node.close()
	paused = false


func _shot(name: String) -> void:
	_unpause()
	await _frames(3)
	root.get_texture().get_image().save_png(out.path_join(name + ".png"))
	print("SHOT ", name)


## Him at `at` (dropped onto what is under it), the camera behind him looking at `look`.
func _put(at: Vector3, look: Vector3) -> void:
	_unpause()
	var space := world.get_world_3d().direct_space_state
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(at + Vector3.UP * 3.0, at + Vector3.DOWN * 60.0, 1, [world.player.get_rid()]))
	if not hit.is_empty():
		at = hit.position + Vector3.UP * 0.1
	world.player.global_position = at
	world.player.velocity = Vector3.ZERO
	world.player.facing_yaw = atan2(look.x - at.x, look.z - at.z)
	world.camera.look_along(Vector3(look.x - at.x, 0.0, look.z - at.z).normalized())
	world.camera.snap()
	await _frames(40)


## The camera set by hand at `from` looking at `to`.
func _view(from: Vector3, to: Vector3) -> void:
	world.camera.set_process(false)
	world.camera.set_physics_process(false)
	world.camera.global_transform = Transform3D.IDENTITY.translated(from).looking_at(to)
	await _frames(5)


func _filter(on: bool) -> void:
	for node in world.get_children():
		if node is N64Filter:
			node.visible = on


func _run() -> void:
	await _frames(60)
	await _shot("start")
	var spot: Transform3D = world.markers["fishing_spot"]
	var water: Vector3 = world.markers["fishing_water"].origin
	await _put(spot.origin, water)
	await _shot("pond_jetty")
	await _put(Vector3(0.0, 3.0, -6.0), Vector3(0.0, 2.0, 30.0))
	await _shot("clearing_to_the_wood")
	# down the Station street's second run, along it
	await _put(Vector3(10.0, 0.0, 117.0), Vector3(-30.0, -10.0, 117.0))
	await _shot("street_filter")
	_filter(false)
	await _shot("street_plain")
	_filter(true)
	await _put(Vector3(5.0, 0.2, 41.0), Vector3(-30.0, 0.2, 30.0))
	await _shot("ring_road")
	await _view(Vector3(0.0, 9.0, 6.0), Vector3(-120.0, 40.0, 1000.0))
	await _shot("vista_grove")
	await _view(Vector3(0.0, -8.0, 118.0), Vector3(-200.0, 20.0, 1000.0))
	await _shot("vista_street")
	await _view(Vector3(0.0, 30.0, 0.0), Vector3(600.0, 20.0, 300.0))
	await _shot("vista_east")
	print("SHOTS DONE ", out)
	quit()
