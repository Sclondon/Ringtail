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


## The ground under `at` (the highest solid thing), or `at` itself over nothing.
func _ground(at: Vector3) -> Vector3:
	var space := world.get_world_3d().direct_space_state
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(at.x, 300.0, at.z), Vector3(at.x, -300.0, at.z), 1, [world.player.get_rid()]))
	return hit.position if not hit.is_empty() else at


## Everything drawn at any distance (ZoneStreaming sets far trees to stop drawing: a view from high up would lose
## the far side of the grove to that, not to the build).
func _no_far() -> void:
	for node in world.find_children("*", "GeometryInstance3D", true, false):
		(node as GeometryInstance3D).visibility_range_end = 100000.0


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


## A point of a face's own frame (x across it, z down it from the hill's middle) in the world (build_town.py's
## FACES: Rural south, Industrial east, Construction north, City west).
func _face(f: int, x: float, y: float, z: float) -> Vector3:
	var turn := PI / 2.0 * f
	return Vector3(x * cos(turn) + z * sin(turn), y, z * cos(turn) - x * sin(turn))


func _run() -> void:
	await _frames(60)
	await _shot("start")
	var spot: Transform3D = world.markers["fishing_spot"]
	var water: Vector3 = world.markers["fishing_water"].origin
	await _put(spot.origin, water)
	await _shot("pond_jetty")
	var spring: Vector3 = world.markers["spring"].origin
	await _put(water + (water - spring).normalized() * 3.0, spring)
	await _shot("pond_spring")
	await _put(Vector3(0.0, 3.0, 6.0), Vector3(0.0, 2.0, -30.0))
	await _shot("clearing_to_the_wood")
	var fir: Vector3 = world.markers["giantfir_0_60"].origin
	await _view(fir + Vector3(12.0, 9.0, 12.0), fir + Vector3.UP * 9.0)
	await _shot("giant_fir")
	await _put(Vector3(0.0, 0.2, 56.0), Vector3(30.0, 0.2, 50.0))
	await _shot("grove_wall")
	await _put(Vector3(5.0, 0.2, 63.0), Vector3(-30.0, 0.2, 55.0))
	await _shot("ring_road")
	_no_far()
	await _view(Vector3(0.0, 85.0, 95.0), Vector3(0.0, 0.0, 0.0))
	await _shot("grove_above")
	await _view(Vector3(0.0, 120.0, 0.5), Vector3(0.0, 0.0, 0.0))
	await _shot("grove_top_down")
	for f in 4:
		var name: String = ["rural", "industrial", "construction", "city"][f]
		await _put(_face(f, 14.0, 0.0, 130.0), _face(f, -20.0, -10.0, 150.0))
		await _shot("street_" + name)
		# (stood on the ground at the face's foot, a person's height up, looking out)
		var foot := _ground(_face(f, 0.0, 0.0, 205.0)) + Vector3.UP * 4.0
		await _view(foot, foot + (_face(f, 0.0, 0.0, 700.0) - _face(f, 0.0, 0.0, 205.0)).normalized() * 500.0 + Vector3.UP * 25.0)
		await _shot("vista_" + name)
	_filter(false)
	await _put(_face(0, 14.0, 0.0, 130.0), _face(0, -20.0, -10.0, 150.0))
	await _shot("street_plain")
	_filter(true)
	await _view(Vector3(0.0, 12.0, 0.0), Vector3(-400.0, 30.0, 900.0))
	await _shot("vista_grove")
	print("SHOTS DONE ", out)
	quit()
