extends SceneTree
## Drives the raccoon round the grove and out to the street for the arcade's preview film: runs, jumps, tail moves,
## a sprint on all fours. Record it with Movie Maker (a window, 960x540 via a temporary override.cfg):
##   godot --path . --audio-driver Dummy --fixed-fps 30 --write-movie <out>/f.png -s res://tests/attract.gd

const SECONDS := 22.0

## [from second, actions held, stick strength]
const PLAN := [
	[0.0, [], 0.0],
	[1.0, [&"move_up"], 0.6],
	[3.0, [&"move_up", &"move_right"], 1.0],
	[4.2, [&"move_up", &"jump"], 1.0],
	[4.6, [&"move_up"], 1.0],
	[5.5, [&"move_up", &"move_left"], 1.0],
	[6.5, [&"tail"], 1.0],
	[7.0, [], 0.0],
	[7.6, [&"move_up", &"sprint"], 1.0],
	[10.5, [&"move_up", &"sprint", &"move_right"], 1.0],
	[11.5, [&"move_up", &"jump"], 1.0],
	[11.9, [&"move_up", &"jump"], 1.0],
	[13.0, [&"move_up"], 1.0],
	[14.0, [&"move_up", &"move_left"], 0.8],
	[15.5, [&"move_up", &"jump"], 1.0],
	[16.0, [&"move_up"], 1.0],
	[17.0, [&"tail"], 1.0],
	[17.6, [&"move_up", &"sprint"], 1.0],
	[20.0, [&"move_up", &"move_right"], 0.7],
]

var _held: Array = []


func _initialize() -> void:
	var world: Node = (load("res://scenes/world1.tscn") as PackedScene).instantiate()
	root.add_child(world)
	_run.call_deferred()


func _run() -> void:
	var start := Time.get_ticks_msec()
	var t := 0.0
	var step := 0
	while t < SECONDS:
		while step < PLAN.size() and t >= float(PLAN[step][0]):
			for a: StringName in _held:
				Input.action_release(a)
			_held = PLAN[step][1]
			for a: StringName in _held:
				Input.action_press(a, float(PLAN[step][2]))
			step += 1
		await process_frame
		# (in frames at the film's 30 a second, however slowly they are drawn)
		t = float(Engine.get_process_frames()) / 30.0
	for a: StringName in _held:
		Input.action_release(a)
	print("attract done in %d ms" % (Time.get_ticks_msec() - start))
	quit()
