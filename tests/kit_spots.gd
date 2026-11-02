extends SceneTree
## Every lost-kit marker (kit_<n>, tools/build_town.py) sits on a surface: something solid within a few centimetres
## under it, nothing solid in the half metre over it, and none in the grove's clearing. Prints each and
## PASSED/FAILED. Headless:
##   godot --headless --path . --audio-driver Dummy --fixed-fps 60 -s res://tests/kit_spots.gd

var world: World
var failures: Array[String] = []


func _initialize() -> void:
	world = (load("res://scenes/world1.tscn") as PackedScene).instantiate()
	root.add_child(world)
	_run.call_deferred()


func _run() -> void:
	for _i in 10:
		await physics_frame
	var space := world.get_world_3d().direct_space_state
	var heart: Vector3 = world.markers.get("grove_heart", Transform3D.IDENTITY).origin
	var count := 0
	for name: String in world.markers:
		if not name.begins_with("kit_"):
			continue
		count += 1
		var at: Vector3 = world.markers[name].origin
		var down := space.intersect_ray(PhysicsRayQueryParameters3D.create(at + Vector3.UP * 0.3, at + Vector3.DOWN * 0.5, 1, [world.player.get_rid()]))
		var gap := INF if down.is_empty() else (down.position as Vector3).distance_to(at)
		var up := space.intersect_ray(PhysicsRayQueryParameters3D.create(at + Vector3.UP * 0.35, at + Vector3.UP * 0.05, 1, [world.player.get_rid()]))
		var outside := Vector2(at.x - heart.x, at.z - heart.z).length() > 21.0
		var ok := gap < 0.15 and up.is_empty() and outside
		print(("ok   " if ok else "FAIL "), name, " at %s: surface %.2f m off, %s over it, %.1f m from the grove's heart" % [at, gap, "room" if up.is_empty() else "something", Vector2(at.x - heart.x, at.z - heart.z).length()])
		if not ok:
			failures.append(name)
	if count != 40:
		failures.append("%d kits" % count)
	print("PASSED" if failures.is_empty() else "FAILED: " + ", ".join(failures))
	quit(0 if failures.is_empty() else 1)
