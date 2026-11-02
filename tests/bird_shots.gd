extends SceneTree
## Pictures of the crow, the owl and the hawk (BirdBody) from four sides and close up, in each pose: folded standing, wings up,
## wings down, gliding, a peck, the owl blinking and its head turned round; a beat filmed live
## (its feathers rippling: `<kind>_live<n>`) and a glide close up. For checking the models and their poses.
##   godot --path . --audio-driver Dummy --fixed-fps 60 --resolution 1600x900 -s res://tests/bird_shots.gd -- --out=<dir>
## Needs a window (kept off the screen).

var out := "user://bird_shots"
var camera: Camera3D
var birds := {}


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.substr(6)
	DirAccess.make_dir_recursive_absolute(out)
	root.position = Vector2i(-3000, 0)
	var stage := Node3D.new()
	root.add_child(stage)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50.0, 35.0, 0.0)
	sun.shadow_enabled = true
	stage.add_child(sun)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.62, 0.74, 0.86)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.6, 0.62, 0.7)
	environment.ambient_light_energy = 0.6
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	stage.add_child(world_environment)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(20, 20)
	ground.mesh = plane
	ground.material_override = Toon.surface(Color(0.55, 0.68, 0.4))
	stage.add_child(ground)
	camera = Camera3D.new()
	camera.fov = 30.0
	stage.add_child(camera)
	for kind: StringName in [&"crow", &"owl", &"hawk"]:
		var bird := BirdBody.make(kind)
		stage.add_child(bird)
		bird.visible = false
		birds[kind] = bird
	_run.call_deferred()


func _frames(count: int) -> void:
	for _i in count:
		await process_frame


func _view(bird: BirdBody, height: float, distance: float, yaw: float, rise := 0.15) -> void:
	var middle := bird.global_position + Vector3.UP * height
	camera.global_position = middle + Vector3(sin(yaw), rise, cos(yaw)).normalized() * distance
	camera.look_at(middle, Vector3.UP)


func _shot(name: String) -> void:
	await _frames(2)
	root.get_texture().get_image().save_png(out.path_join(name + ".png"))
	print("SHOT ", name)


## Four sides, and close up from the front quarter.
func _round(bird: BirdBody, name: String, height: float, distance: float, rise := 0.15) -> void:
	for view: Array in [["front", 0.0], ["left", PI * 0.5], ["back", PI], ["right", -PI * 0.5], ["quarter", PI * 0.25]]:
		_view(bird, height, distance, view[1], rise)
		await _shot("%s_%s" % [name, view[0]])


func _run() -> void:
	for kind: StringName in birds:
		var bird: BirdBody = birds[kind]
		var big: float = {&"crow": 1.0, &"owl": 1.4, &"hawk": 1.2}[kind]
		for other: StringName in birds:
			birds[other].visible = other == kind
		# Standing, folded
		bird.fold = 1.0
		bird.flap = 0.0
		bird.tuck = 0.0
		bird.position = Vector3.ZERO
		await _frames(90)
		await _round(bird, "%s_stand" % kind, 0.22 * big, 1.6 * big)
		_view(bird, 0.36 * big, 0.6 * big, 0.5, 0.1)
		await _shot("%s_face" % kind)
		_view(bird, 0.3 * big, 1.0 * big, 0.0, 3.0)
		await _shot("%s_stand_above" % kind)
		# Head round and a blink (the owl), a peck (the crow)
		bird.look_at_point(bird.global_position + Vector3(-3.0, 0.3, -2.0))
		await _frames(30)
		_view(bird, 0.3 * big, 1.2 * big, 0.4)
		await _shot("%s_look" % kind)
		bird.look_at_point(Vector3.INF)
		bird.blink()
		await _frames(6)
		_view(bird, 0.4 * big, 0.7 * big, 0.0)
		await _shot("%s_blink" % kind)
		bird.peck()
		await _frames(10)
		_view(bird, 0.25 * big, 1.2 * big, PI * 0.5)
		await _shot("%s_peck" % kind)
		# Flying: wings up, wings down (frozen at a phase), gliding
		bird.position = Vector3(0.0, 0.8, 0.0)
		bird.fold = 0.0
		bird.tuck = 1.0
		bird.flap = 1.0
		await _frames(60)
		for phase: Array in [["up", PI * 0.5], ["down", -PI * 0.5]]:
			bird.flap_rate = 0.0
			bird._phase = phase[1]
			await _frames(3)
			await _round(bird, "%s_wings%s" % [kind, phase[0]], 0.3 * big, 2.6 * big, 0.25)
		# One beat, eight frames of it, from the side (facing right, as the reference photos are) and the front
		bird.flap_rate = 0.0
		for k in 8:
			bird._phase = TAU * k / 8.0
			await _frames(2)
			_view(bird, 0.3 * big, 2.4 * big, PI * 0.5, 0.05)
			await _shot("%s_beat_side%d" % [kind, k])
			_view(bird, 0.3 * big, 2.4 * big, 0.0, 0.05)
			await _shot("%s_beat_front%d" % [kind, k])
			_view(bird, 0.3 * big, 2.4 * big, PI * 0.3, 0.9)
			await _shot("%s_beat_above%d" % [kind, k])
		# A beat filmed live (the springs see the wing move), every third frame
		bird.flap_rate = {&"crow": 17.0, &"owl": 10.0, &"hawk": 11.0}[kind]
		for k in 12:
			bird.position = Vector3(0.0, 0.8, 0.0)
			await _frames(3)
			_view(bird, 0.3 * big, 2.0 * big, PI * 0.3, 0.35)
			await _shot("%s_live%d" % [kind, k])
		bird.flap_rate = 0.0
		bird.flap = 0.0
		await _frames(60)
		await _round(bird, "%s_glide" % kind, 0.3 * big, 2.6 * big, 0.6)
		_view(bird, 0.3 * big, 1.1 * big, PI * 0.35, 0.8)
		await _shot("%s_glide_close" % kind)
		bird.flare = 1.0
		bird.tuck = 0.0
		await _frames(60)
		_view(bird, 0.3 * big, 2.4 * big, PI * 0.5, 0.05)
		await _shot("%s_flare_side" % kind)
		_view(bird, 0.3 * big, 2.4 * big, PI * 0.25, 0.3)
		await _shot("%s_flare_quarter" % kind)
		bird.flare = 0.0
		bird.flap_rate = 12.0 if kind == &"crow" else 7.0
	print("SHOTS DONE ", out)
	quit()
