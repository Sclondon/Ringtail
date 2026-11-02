extends SceneTree
## A row of every food a Crumb can be (Pickup.FOODS), shaded as in the game, with the HUD's apple icon:
##   godot --path . --audio-driver Dummy --resolution 1280x480 -s res://tests/food_shots.gd -- --out=<dir>
## Needs a window (kept off the screen).

var out := "user://food_shots"


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.substr(6)
	DirAccess.make_dir_recursive_absolute(out)
	root.position = Vector2i(-3000, 0)
	var stage := Node3D.new()
	root.add_child(stage)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45.0, -30.0, 0.0)
	stage.add_child(sun)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(0.45, 0.62, 0.85)
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color(0.6, 0.62, 0.7)
	stage.add_child(environment)
	var count: int = Pickup.FOODS.size()
	for k in count:
		var food: Array = Pickup.FOODS[k]
		var model: Node3D = (food[0] as PackedScene).instantiate()
		model.position = Vector3((k - (count - 1) * 0.5) * 0.42, 0.0, 0.0)
		model.rotation = Vector3(food[2], 0.5, 0.0)
		model.scale = Vector3.ONE * float(food[3])
		stage.add_child(model)
		Toon.apply(model)
	var camera := Camera3D.new()
	camera.fov = 45.0
	stage.add_child(camera)
	camera.look_at_from_position(Vector3(0.0, 0.7, 2.2), Vector3(0.0, 0.12, 0.0))
	var layer := CanvasLayer.new()
	root.add_child(layer)
	var icon := Icon.make(Icon.Kind.CRUMB, 64.0)
	icon.position = Vector2(20, 20)
	icon.size = Vector2(64, 64)
	layer.add_child(icon)
	_shoot.call_deferred()


func _shoot() -> void:
	for _i in 5:
		await process_frame
	root.get_texture().get_image().save_png(out.path_join("foods.png"))
	print("FOOD SHOTS DONE ", out)
	quit()
