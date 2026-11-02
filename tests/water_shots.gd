extends SceneTree
## The grove's water (GroveWater): the spring pool bubbling on its outcrop, its waterfall into the pond, the pond.
## Prints what was made; in a window shoots it from the spawn, the falls close up from the side and the front, the
## spring pool from above, and the falls at night. Window only (pictures cannot be taken headless):
##   godot --path . --audio-driver Dummy --resolution 960x540 -s res://tests/water_shots.gd -- --out=<dir>

var out := ""


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
	var world: World = (load("res://scenes/world1.tscn") as PackedScene).instantiate()
	root.add_child(world)
	_run.call_deferred(world)


func _run(world: World) -> void:
	for _i in 90:
		await process_frame
	var water := world.get_node_or_null(^"GroveWater") as GroveWater
	if water == null or water.falls == null:
		print("FAILED: no grove water (%s)" % [water])
		quit()
		return
	var top := water.falls.top
	var bottom := water.falls.bottom
	var pool := water.spring_water.global_position
	print("spring pool at %s size %s; falls %s -> %s (%.2f m); pond %s" % [pool, water.spring_water.size, top, bottom, top.y - bottom.y, water.pond.global_position if water.pond else null])
	if out == "":
		print("PASSED")
		quit()
		return
	for c in world.find_children("*", "CanvasLayer", true, false):
		c.visible = false
	var eye := Camera3D.new()
	world.add_child(eye)
	eye.current = true
	var way := Vector3(bottom.x - top.x, 0.0, bottom.z - top.z).normalized()
	var side := way.cross(Vector3.UP).normalized()
	var spawn: Vector3 = world.markers["spawn"].origin if world.markers.has("spawn") else world.player.global_position
	var shots := [
		["spawn", spawn + Vector3.UP * 1.4, (top + bottom) * 0.5],
		["falls_side", (top + bottom) * 0.5 + side * 3.2 + way * 1.2 + Vector3.UP * 0.4, (top + bottom) * 0.5],
		["falls_front", bottom + way * 4.0 + Vector3.UP * 0.8, (top + bottom) * 0.5],
		["spring_above", pool + Vector3.UP * 3.2 + way * 0.6, pool],
		["foot", bottom + way * 1.6 + side * 0.8 + Vector3.UP * 0.5, bottom],
	]
	for shot: Array in shots:
		eye.global_position = shot[1]
		eye.look_at(shot[2])
		for _i in 20:
			await process_frame
		root.get_viewport().get_texture().get_image().save_png("%s/water_%s.png" % [out, shot[0]])
	if DayNight.current:
		DayNight.current.set_hour(23.0)
		eye.global_position = shots[2][1]
		eye.look_at(shots[2][2])
		for _i in 30:
			await process_frame
		root.get_viewport().get_texture().get_image().save_png("%s/water_night.png" % out)
	print("PASSED")
	quit()
