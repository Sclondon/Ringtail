extends SceneTree
## The day going round (DayNight), the clock held and jumped: by day the sun high and bright, danger 1, the hawk
## seeing far, the owl not hunting; at night the sun down and the moon lighting it dimmer but not black, the windows
## lit, lamps on, fireflies out, danger 0, the owl hunting and the hawk not. Prints PASSED or FAILED. Headless:
##   godot --headless --path . --audio-driver Dummy --fixed-fps 60 -s res://tests/day_night_test.gd

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
	for _i in 10:
		await process_frame
	var day := DayNight.current
	_check(day != null, "a day going round")
	var sun: DirectionalLight3D = day._sun
	var before := day.hour
	for _i in 30:
		await process_frame
	_check(day.hour > before, "the clock goes on (%.3f -> %.3f)" % [before, day.hour])
	day.held = true
	day.set_hour(12.0)
	await process_frame
	var noon_energy := sun.light_energy
	var noon_window: float = day._windows[0].get_shader_parameter(&"emission") if not day._windows.is_empty() else 0.0
	_check(day.danger > 0.95 and day.night < 0.05 and noon_energy > 1.0, "midday: bright (%.2f), dangerous (%.2f)" % [noon_energy, day.danger])
	_check(DayNight.by_day(1.8, 0.0) > 1.7 and not DayNight.is_night(), "by day the hawk sees far, the owl does not hunt")
	day.set_hour(0.5)
	day._light_nearest_lamps()
	await process_frame
	var night_window: float = day._windows[0].get_shader_parameter(&"emission") if not day._windows.is_empty() else 0.0
	_check(day.night > 0.95 and day.danger < 0.05, "midnight: night (%.2f), safe (%.2f)" % [day.night, day.danger])
	_check(sun.light_energy > 0.25 and sun.light_energy < noon_energy * 0.6, "moonlight: dimmer (%.2f) but not black" % sun.light_energy)
	_check(not day._windows.is_empty() and night_window > noon_window + 0.4 and day.lit_houses > 5, "windows lit at night (%.2f -> %.2f, %d houses)" % [noon_window, night_window, day.lit_houses])
	_check(day._lamp_glow != null and day._lamp_glow.visible and day._lamps.any(func(l: Light3D) -> bool: return l.visible), "lamps on (%d along the poles)" % day._lamp_spots.size())
	_check(day._flies == null or day._flies.emitting, "fireflies in the grove")
	_check(DayNight.is_night() and DayNight.by_day(1.8, 0.0) < 0.05, "at night the owl hunts, the hawk does not")
	day.set_hour(6.5)
	await process_frame
	var dawn := day.danger
	day.set_hour(17.5)
	await process_frame
	_check(dawn > 0.0 and dawn < 1.0 and day.danger > 0.0 and day.danger < 1.0, "dawn and dusk between (%.2f, %.2f)" % [dawn, day.danger])
	print("PASSED" if failures.is_empty() else "FAILED: " + ", ".join(failures))
	quit()
