extends SceneTree
## Pictures of the plant generators (GameCommon undergrowth): every FlowerGen preset in three seeds, every BrambleGen
## preset, Warren's fern, bush and moss (Undergrowth), the raccoon among them for size; a lupine, a foxglove, a rose and a
## bramble close from four sides; prints each one's triangles. Needs a window:
##   godot --path . --audio-driver Dummy --resolution 1280x720 -s res://tests/plant_shots.gd -- --out=<dir>

var out := "user://plant_shots"
var stage: Node3D
var camera: Camera3D


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.substr(6)
	DirAccess.make_dir_recursive_absolute(out)
	stage = Node3D.new()
	root.add_child(stage)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.62, 0.72, 0.8)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.55, 0.6, 0.65)
	env.environment.ambient_light_energy = 0.7
	stage.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.9, 0.6, 0.0)
	sun.shadow_enabled = true
	stage.add_child(sun)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(60, 60)
	ground.mesh = plane
	var soil := StandardMaterial3D.new()
	soil.albedo_color = Color(0.36, 0.42, 0.26)
	ground.material_override = soil
	stage.add_child(ground)
	camera = Camera3D.new()
	camera.fov = 40.0
	stage.add_child(camera)
	camera.current = true
	_run.call_deferred()


func _put(mesh: Mesh, at: Vector3, size := 1.0) -> MeshInstance3D:
	var shown := MeshInstance3D.new()
	shown.mesh = mesh
	shown.position = at
	shown.scale = Vector3.ONE * size
	stage.add_child(shown)
	return shown


func _shoot(name: String, from: Vector3, to: Vector3) -> void:
	camera.position = from
	camera.look_at(to)
	for _i in 4:
		await process_frame
	root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, name])


func _tris(mesh: Mesh) -> int:
	var total := 0
	for s in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(s)
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		total += indices.size() / 3 if indices.size() > 0 else (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	return total


func _run() -> void:
	var raccoon: Node3D = (load("res://models/raccoon.glb") as PackedScene).instantiate()
	# Flowers: a row per preset, three seeds each
	var names: Array = FlowerGen.names()
	for r in names.size():
		var gen := FlowerGen.preset(names[r])
		for s in 3:
			gen.seed = s + 1
			var mesh := gen.mesh()
			_put(mesh, Vector3(s * 0.8 - 0.8, 0.0, -r * 0.9))
			if s == 0:
				print("FLOWER %s tris %d" % [names[r], _tris(mesh)])
	raccoon.position = Vector3(1.4, 0.0, -2.0)
	raccoon.scale = Vector3.ONE * 0.9
	stage.add_child(raccoon)
	await _shoot("flowers_a", Vector3(0.0, 1.6, 2.6), Vector3(0.0, 0.2, -2.0))
	await _shoot("flowers_b", Vector3(0.0, 1.6, -3.4), Vector3(0.0, 0.2, -7.5))
	await _shoot("flowers_above", Vector3(0.0, 9.0, -4.0), Vector3(0.0, 0.0, -4.5))
	for child in stage.get_children():
		if child is MeshInstance3D and child.mesh is ArrayMesh:
			child.queue_free()
	# Brambles, Warren's plants, and him
	var bnames: Array = BrambleGen.names()
	for k in bnames.size():
		var gen := BrambleGen.preset(bnames[k])
		var mesh := gen.mesh()
		_put(mesh, Vector3((k % 3) * 4.5 - 4.5, 0.0, -floorf(k / 3.0) * 4.5))
		print("BRAMBLE %s tris %d" % [bnames[k], _tris(mesh)])
	for kind in [Undergrowth.Kind.FERN, Undergrowth.Kind.BUSH, Undergrowth.Kind.MOSS]:
		var mesh := Undergrowth.mesh(kind)
		var shown := _put(mesh, Vector3(-4.0 + kind * 2.0, 0.0, 3.0))
		shown.material_override = Undergrowth.shared_material(kind)
		print("UNDERGROWTH %d tris %d" % [kind, _tris(mesh)])
	raccoon.position = Vector3(1.6, 0.0, 1.2)
	await _shoot("brambles", Vector3(0.0, 4.5, 9.0), Vector3(0.0, 0.6, -2.0))
	await _shoot("ferns", Vector3(-1.0, 1.2, 6.0), Vector3(-2.0, 0.4, 3.0))
	for child in stage.get_children():
		if child is MeshInstance3D and child.mesh is ArrayMesh:
			child.queue_free()
	# Close from four sides
	var close: Array = [FlowerGen.preset("Lupine").mesh(), FlowerGen.preset("Foxglove").mesh(),
		FlowerGen.preset("Garden rose").mesh(), FlowerGen.preset("Oxeye daisy").mesh()]
	for k in close.size():
		_put(close[k], Vector3(k * 0.7 - 1.05, 0.0, 0.0))
	raccoon.position = Vector3(1.7, 0.0, 0.0)
	var sides := {"front": Vector3(0, 0.7, 3.0), "left": Vector3(-3.0, 0.7, 0), "back": Vector3(0, 0.7, -3.0), "right": Vector3(3.0, 0.7, 0)}
	for side: String in sides:
		await _shoot("close_" + side, sides[side], Vector3(0.0, 0.3, 0.0))
	for child in stage.get_children():
		if child is MeshInstance3D and child.mesh is ArrayMesh:
			child.queue_free()
	_put(BrambleGen.preset("Ripe").mesh(), Vector3.ZERO)
	raccoon.position = Vector3(2.2, 0.0, 0.0)
	var far_sides := {"front": Vector3(0, 1.5, 5.5), "left": Vector3(-5.5, 1.5, 0), "back": Vector3(0, 1.5, -5.5), "top": Vector3(0.1, 7.0, 0)}
	for side: String in far_sides:
		await _shoot("bramble_" + side, far_sides[side], Vector3(0.0, 0.6, 0.0))
	await _shoot("bramble_berries", Vector3(1.2, 1.2, 1.6), Vector3(0.5, 0.9, 0.3))
	print("SHOTS DONE")
	quit()
