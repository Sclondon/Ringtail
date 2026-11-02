extends SceneTree
## Measures the raccoon's feet in each gait on the playground: how far a foot slides while it is down (it should
## stay put), how low any foot or paw goes against the lowest it is ever set (through the ground?), and his
## footfalls a second. Headless:
##   godot --headless --path . --audio-driver Dummy --fixed-fps 60 -s res://tests/gait_check.gd

## [name, stick push, scurrying]
const GAITS := [["sneak", 0.25, false], ["walk", 0.62, false], ["run", 0.85, false], ["bound", 1.0, false], ["scurry", 0.85, true], ["scurry1", 1.0, true]]
const FRAMES := 90

var player: Player
var rig: RaccoonRig


func _initialize() -> void:
	var level: Node3D = load("res://scenes/playground.tscn").instantiate()
	root.add_child(level)
	_run.call_deferred(level)


func _run(level: Node3D) -> void:
	await process_frame
	player = level.player
	rig = player.get_node(^"Rig") as RaccoonRig
	for gait: Array in GAITS:
		await _measure(gait[0], gait[1], gait[2])
	quit()


func _measure(name: String, push: float, scurrying: bool) -> void:
	(player.get_node(^"Scurry") as Scurry).button = scurrying
	for action: StringName in [&"move_up", &"duck", &"sprint", &"jump", &"tail"]:
		Input.action_release(action)
	player.global_position = Vector3(12.0, 0.05, -12.0)
	player.velocity = Vector3.ZERO
	for _i in 30:
		await physics_frame
	Input.action_press(&"move_up", push)
	for _i in 15:
		await physics_frame
	# (put back across the field from the way he is going, so he has the length of it ahead of him)
	var way := Vector3(player.velocity.x, 0.0, player.velocity.z).normalized()
	# (and off to one side, clear of the boxes in the middle)
	var aside := way.cross(Vector3.UP) * 14.0
	player.global_position = Vector3(-way.x * 22.0 + aside.x, 0.05, -way.z * 22.0 + aside.z)
	for _i in 40:
		await physics_frame
	var parts: Array[Node3D] = []
	parts.append_array(rig._feet)
	parts.append_array(rig._hands)
	var track: Array = []
	var speed := 0.0
	for _i in FRAMES:
		await physics_frame
		speed += Vector2(player.velocity.x, player.velocity.z).length() / FRAMES
		var frame: Array[Vector3] = []
		for part in parts:
			frame.append(part.global_position - Vector3(0.0, player.global_position.y, 0.0))
		track.append(frame)
	var slip := [0.0, 0.0, 0.0, 0.0]
	var lowest := [INF, INF, INF, INF]
	var falls := 0
	for k in parts.size():
		for frame: Array in track:
			lowest[k] = minf(lowest[k], frame[k].y)
		var down_at = null
		for frame: Array in track:
			var at: Vector3 = frame[k]
			# (down: within a little of the lowest it goes)
			if at.y < lowest[k] + 0.004:
				if down_at == null:
					down_at = at
					falls += 1
				slip[k] = maxf(slip[k], Vector2(at.x - down_at.x, at.z - down_at.z).length())
			else:
				down_at = null
	print("%-7s speed %.2f m/s  falls/s %.1f  slip hind %.3f %.3f fore %.3f %.3f m  lowest hind %.3f %.3f fore %.3f %.3f  sneaking %s quad %.2f" % [
		name, speed, falls / (FRAMES / 60.0), slip[0], slip[1], slip[2], slip[3], lowest[0], lowest[1], lowest[2], lowest[3],
		player.is_sneaking, rig._quad])
