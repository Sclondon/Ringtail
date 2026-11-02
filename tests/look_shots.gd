extends SceneTree
## Pictures of the looks: the town's cats in a row (FurLook.CAT_LOOKS) from four sides, his fur types in a row, and
## (in World 1) the pause screen and the model editor over it. Needs a window (kept off the screen):
##   godot --path . --audio-driver Dummy --fixed-fps 60 --resolution 1280x720 -s res://tests/look_shots.gd -- --out=<dir> [cats] [furs] [shapes] [menus]
## (menus also at --resolution 390x844 for a phone)

var out := "user://look_shots"
var only: Array[String] = []
## The "shapes" row: his own, then the fur laid back, stood out, thinned, long, a big wide mane, a long thick tail,
## and Gloaming's wavy and curly textures.
const SHAPES := [{}, {"body": [1.0, 0.7, 1.0]}, {"body": [1.0, -0.7, 1.0]}, {"body": [1.0, 0.0, 0.35]},
	{"body": [1.9, 0.0, 1.0]}, {"mane": [2.2, -0.3, 1.0, 2.2]}, {"tail": [1.6, 1.8]}, {"texture": "wavy"}, {"texture": "curly", "fur": "shaggy"}]


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.substr(6)
		else:
			only.append(arg)
	DirAccess.make_dir_recursive_absolute(out)
	root.position = Vector2i(-3000, 0)
	_run.call_deferred()


func _frames(count: int) -> void:
	for _i in count:
		await process_frame


func _shoot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join(name + ".png"))
	print("SHOT ", name)


func _run() -> void:
	if only.is_empty() or "cats" in only:
		await _row("cats")
	if only.is_empty() or "furs" in only:
		await _row("furs")
	if only.is_empty() or "shapes" in only:
		await _row("shapes")
	for what: String in SINGLES:
		if what in only:
			await _singles(what)
	if "eyes" in only:
		await _eyes()
	if only.is_empty() or "menus" in only:
		await _menus()
	print("LOOK SHOTS DONE ", out)
	quit()


## A row of figures on a stage, from the front, a side, behind and a quarter.
func _row(what: String) -> void:
	var stage := Node3D.new()
	root.add_child(stage)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.5, 0.62, 0.72)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.6, 0.6, 0.65)
	var lit := WorldEnvironment.new()
	lit.environment = environment
	stage.add_child(lit)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45.0, 30.0, 0.0)
	sun.shadow_enabled = true
	stage.add_child(sun)
	var count := FurLook.CAT_LOOKS.size() if what == "cats" else (SHAPES.size() if what == "shapes" else FurLook.TYPES.size())
	var gap := 0.9 if what == "cats" else 1.1
	for k in count:
		var stand := FurEditor.Stand.new()
		var rig: RaccoonRig
		if what == "cats":
			var look: Dictionary = (FurLook.CAT_LOOKS[k] as Dictionary).duplicate(true)
			rig = CatRig.new()
			rig.model = load(FurLook.model_path("cat", look["fur"]))
			rig.look = look
			rig.scale = Vector3.ONE * 0.85
		else:
			rig = RaccoonRig.new()
			rig.model = load("res://models/raccoon.glb")
			rig.key_poses = false
			rig.cap_hand = false
			rig.look = SHAPES[k].duplicate(true) if what == "shapes" else {"fur": FurLook.TYPES[k]}
		rig.dusty = false
		stand.add_child(rig)
		stand.position = Vector3((k - (count - 1) * 0.5) * gap, 0.0, 0.0)
		stage.add_child(stand)
		rig.restyle()
	var eye := Camera3D.new()
	eye.fov = 30.0
	stage.add_child(eye)
	eye.make_current()
	await _frames(30)
	var far := count * gap * 1.05
	for view: Array in [["front", Vector3(0, 0.25, 1)], ["side", Vector3(1, 0.25, 0.02)], ["back", Vector3(0, 0.25, -1)], ["quarter", Vector3(0.6, 0.45, 0.8)]]:
		var middle := Vector3(0.0, 0.4, 0.0)
		var from: Vector3 = (view[1] as Vector3).normalized() * (far if view[0] != "side" else 3.2)
		eye.look_at_from_position(middle + from, middle)
		await _frames(3)
		await _shoot("%s_%s" % [what, view[0]])
	stage.queue_free()
	await _frames(2)


func _menus() -> void:
	var world: World = (load("res://scenes/world1.tscn") as PackedScene).instantiate()
	root.add_child(world)
	await _frames(40)
	var size := root.get_visible_rect().size
	var tag := "%dx%d" % [size.x, size.y]
	await _shoot("game_" + tag)
	world.hud.pause.open()
	await _frames(5)
	await _shoot("pause_" + tag)
	world.hud.pause._edit()
	await _frames(40)
	await _shoot("editor_" + tag)
	var editor: FurEditor = root.find_children("*", "FurEditor", true, false)[0]
	editor._choose("cat", 4)
	editor._fill()
	await _frames(40)
	await _shoot("editor_cat_" + tag)
	editor._choose("raccoon", 0)
	editor.look["fur"] = "cones"
	editor.look["marks"] = "frosted"
	editor.look["texture"] = "straight"
	editor.look["mane"] = [1.6, -0.2, 0.8, 1.6]
	editor._rig.look = editor.look.duplicate(true)
	editor._rig.restyle()
	editor._fill()
	await _frames(40)
	await _shoot("editor_cones_" + tag)
	editor._face = true
	editor._frame()
	await _frames(20)
	await _shoot("editor_face_" + tag)
	root.get_tree().paused = false


## Each cat's head close up from the front, a quarter and the side (the user, 2026-11-02: "the cat eyes need work").
func _eyes() -> void:
	var stage := Node3D.new()
	root.add_child(stage)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.5, 0.62, 0.72)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.6, 0.6, 0.65)
	var lit := WorldEnvironment.new()
	lit.environment = environment
	stage.add_child(lit)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45.0, 30.0, 0.0)
	stage.add_child(sun)
	var eye := Camera3D.new()
	eye.fov = 30.0
	stage.add_child(eye)
	eye.make_current()
	for k in FurLook.CAT_LOOKS.size():
		var stand := FurEditor.Stand.new()
		var look: Dictionary = (FurLook.CAT_LOOKS[k] as Dictionary).duplicate(true)
		var rig := CatRig.new()
		rig.model = load(FurLook.model_path("cat", look["fur"]))
		rig.look = look
		rig.scale = Vector3.ONE * 0.85
		rig.dusty = false
		stand.add_child(rig)
		stage.add_child(stand)
		rig.restyle()
		await _frames(20)
		var skeleton: Skeleton3D = rig._skeleton
		var head := skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.find_bone("head")).origin
		var ahead := rig.global_basis.z
		for view: Array in [["front", 0.0], ["quarter", 0.7], ["side", 1.45]]:
			var from := ahead.rotated(Vector3.UP, view[1]) * 0.75 + Vector3.UP * 0.05
			eye.look_at_from_position(head + from, head)
			await _frames(3)
			await _shoot("eyes_%d_%s" % [k, view[0]])
		stand.queue_free()
		await _frames(2)
	stage.queue_free()


## Rows of single figures, each close up from the front, its side and a quarter: the fur shapes, parts and fixes.
const SINGLES := {
	"spikes": [{}, {"shape": "teardrop"}, {"shape": "ribbon"}, {"shape": "wavy"}, {"shape": "curl"}, {"shape": "blunt"},
		{"shape": "forked"}],
	"parts": [{"mane": [1.0, 0.0, 1.0, 0.4]}, {"mane": [1.0, 0.0, 1.0, 2.4]}, {"parts": {"back": [2.0, 2.0, 1.0]}},
		{"parts": {"arms": [1.0, 1.0, 0.2]}}, {"parts": {"legs": [0.4, 1.0, 1.0]}}, {"parts": {"crown": [2.2, 1.6, 1.0]}}],
	"mane": [{"mane": [1.0, 0.0, 1.0, 0.4]}, {}, {"mane": [1.0, 0.0, 1.0, 2.4]}],
	"clip": [{"body": [1.0, 0.9, 1.0]}, {"body": [1.0, -0.9, 1.0]}, {"body": [2.2, 0.0, 1.0]},
		{"body": [1.6, 0.9, 1.0], "run": true}, {"run": true}, {"tail": [1.0, 2.0]}, {"tail": [1.6, 1.0]}],
}


func _singles(what: String) -> void:
	var stage := Node3D.new()
	root.add_child(stage)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.5, 0.62, 0.72)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.55, 0.55, 0.6)
	environment.ambient_light_energy = 0.6
	var lit := WorldEnvironment.new()
	lit.environment = environment
	stage.add_child(lit)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45.0, 30.0, 0.0)
	sun.light_energy = 0.9
	stage.add_child(sun)
	var eye := Camera3D.new()
	eye.fov = 30.0
	stage.add_child(eye)
	eye.make_current()
	var looks: Array = SINGLES[what]
	for k in looks.size():
		var look: Dictionary = (looks[k] as Dictionary).duplicate(true)
		var running: bool = look.get("run", false)
		look.erase("run")
		var stand := FurEditor.Stand.new()
		var rig := RaccoonRig.new()
		rig.model = load("res://models/raccoon.glb")
		rig.key_poses = false
		rig.cap_hand = false
		rig.dusty = false
		rig.look = look
		stand.add_child(rig)
		stage.add_child(stand)
		if running:
			# (bounding flat out on the spot)
			stand.velocity = Vector3(0.0, 0.0, 6.0)
			stand.is_sprinting = true
		rig.restyle()
		await _frames(40)
		for view: Array in [["front", Vector3(0, 0.15, 1)], ["side", Vector3(1, 0.15, 0.02)], ["quarter", Vector3(0.7, 0.35, 0.7)]]:
			var middle := Vector3(0.0, 0.95, 0.0) if what == "mane" else Vector3(0.0, 0.45, -0.1)
			eye.look_at_from_position(middle + (view[1] as Vector3).normalized() * (1.1 if what == "mane" else 3.0), middle)
			await _frames(3)
			await _shoot("%s_%d_%s" % [what, k, view[0]])
		stand.queue_free()
		await _frames(2)
	stage.queue_free()
