extends SceneTree
## The "Giant fir" preset (TreeGen) beside a Fir and the great oak in the playground, from the side, closer on its
## pads, and from above; prints its pads. Window:
##   godot --path . --audio-driver Dummy --resolution 960x540 -s res://tests/giant_fir_shots.gd -- --out=<dir>

var out := ""


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
	_run.call_deferred()


func _run() -> void:
	var level: Node3D = load("res://scenes/playground.tscn").instantiate()
	root.add_child(level)
	for c in level.find_children("*", "CanvasLayer", true, false):
		c.visible = false
	var at := Vector3(40.0, 0.0, -40.0)
	var fir := TreeGen.preset("Giant fir")
	fir.seed = 3
	var body := fir.body()
	body.position = at
	level.add_child(body)
	print("GIANT FIR pads %d" % fir.pad_tops().size())
	var plain := TreeGen.preset("Fir")
	plain.seed = 5
	var p := plain.instance()
	p.position = at + Vector3(9.0, 0.0, 0.0)
	p.scale = Vector3.ONE * 1.6
	level.add_child(p)
	var eye := Camera3D.new()
	level.add_child(eye)
	eye.current = true
	var views := {"side": [at + Vector3(4.0, 10.0, 34.0), at + Vector3(4.0, 13.0, 0.0)], "pads": [at + Vector3(6.0, 9.0, 11.0), at + Vector3(0.0, 7.0, 0.0)], "above": [at + Vector3(0.0, 45.0, 0.1), at]}
	for k: String in views:
		eye.global_position = views[k][0]
		eye.look_at(views[k][1])
		for _i in 6:
			await process_frame
		root.get_viewport().get_texture().get_image().save_png("%s/giant_fir_%s.png" % [out, k])
	print("SHOT")
	quit()
