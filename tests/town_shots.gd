extends SceneTree
## Pictures of the town as played (tools/build_town.py): the start in the grove, the shrine, the street under the
## retaining walls, the steps, the antique shop's plaza, the bath house chimney, the view over the rail at the back.
##   godot --path . --audio-driver Dummy --fixed-fps 60 --resolution 1280x720 -s res://tests/town_shots.gd -- --out=<dir>
## Needs a window (kept off the screen).

var out := "user://town_shots"
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


func _shot(name: String) -> void:
	await _frames(3)
	root.get_texture().get_image().save_png(out.path_join(name + ".png"))
	print("SHOT ", name)


## Puts him at `at` (dropped on whatever is under it) facing `look`.
func _put(at: Vector3, look: Vector3) -> void:
	var space := world.get_world_3d().direct_space_state
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(at + Vector3.UP * 4.0, at + Vector3.DOWN * 30.0, 1, [world.player.get_rid()]))
	if not hit.is_empty():
		at = hit.position + Vector3.UP * 0.1
	world.player.global_position = at
	world.player.velocity = Vector3.ZERO
	world.player.facing_yaw = atan2(look.x - at.x, look.z - at.z)
	world.camera.snap()
	await _frames(40)


## A point on the lot round the road at `tenth` (0..10 round) and `r` out from the middle.
func _lot(tenth: float, r: float) -> Vector3:
	var a := TAU * tenth / 10.0
	return Vector3(cos(a) * r, 0.0, sin(a) * r)


func _run() -> void:
	await _frames(60)
	await _shot("start")
	await _put(world.markers["grove_heart"].origin + Vector3(0.0, 0.0, 3.0), Vector3(0.5, 7.0, -6.0))
	await _shot("shrine")
	await _put(_lot(0.3, 34.6), _lot(1.3, 34.6))
	await _shot("street")
	await _put(_lot(5.8, 35.0), _lot(5.05, 35.0))
	await _shot("steps")
	await _put(_lot(3.5, 31.0), _lot(3.5, 40.0))
	await _shot("plaza")
	await _put(_lot(2.3, 34.8), _lot(2.6, 50.0))
	await _shot("bath_house")
	await _put(_lot(0.544, 54.6), _lot(0.544, 120.0))
	await _shot("over_the_rail")
	await _put(_lot(5.544, 54.6), _lot(5.3, 120.0))
	await _shot("over_the_rail_2")
	# Out towards the edge: from the top of the grove, and from the road through a gap between the houses
	await _put(Vector3(-5.5, 9.0, -1.0), Vector3(-100.0, 0.0, -10.0))
	await _shot("edge_from_grove")
	await _put(_lot(2.0, 31.0), _lot(2.0, 100.0))
	await _shot("edge_from_road")
	await _put(_lot(7.0, 30.0), _lot(7.0, 100.0))
	await _shot("edge_from_road_2")
	print("SHOTS DONE ", out)
	quit()
