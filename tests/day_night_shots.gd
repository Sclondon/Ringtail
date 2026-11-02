extends SceneTree
## Pictures of the day going round (DayNight): dawn, noon, evening and night, from the spawn in the grove and from the
## ring road looking down a street, through the pixel filter.
##   godot --path . --audio-driver Dummy --fixed-fps 60 --resolution 1280x720 -s res://tests/day_night_shots.gd -- --out=<dir>
## Needs a window (kept off the screen).

const HOURS := {"dawn": 6.4, "noon": 12.0, "evening": 17.6, "night": 0.5}

var out := "user://day_night_shots"
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


func _run() -> void:
	await _frames(60)
	var day := DayNight.current
	day.held = true
	var heart: Vector3 = world.markers["grove_heart"].origin
	# The ring road where the south street leaves it, looking down the street
	var road := heart + Vector3(0.0, 0.0, 41.0)
	for name: String in HOURS:
		day.set_hour(HOURS[name])
		await _put(heart + Vector3(0.0, 0.0, 3.0), heart + Vector3(0.0, 0.0, 30.0))
		await _shot(name + "_grove")
		await _put(road, road + Vector3(0.0, -10.0, 30.0))
		day._light_nearest_lamps()
		await _shot(name + "_road")
		var lots := heart + Vector3(sin(0.5), 0.0, cos(0.5)) * 44.0
		await _put(lots, lots + Vector3(sin(0.5), 0.3, cos(0.5)) * 20.0)
		day._light_nearest_lamps()
		var eye := Camera3D.new()
		world.add_child(eye)
		var foot := world.player.global_position
		eye.look_at_from_position(foot + Vector3(0.0, 2.0, 0.0), foot + Vector3(sin(0.5) * 20.0, 5.0, cos(0.5) * 20.0))
		eye.make_current()
		await _shot(name + "_houses")
		eye.queue_free()
		world.camera.make_current()
	quit()
