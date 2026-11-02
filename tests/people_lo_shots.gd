extends SceneTree
## The town's people on the low boy (models/boy_tp.glb, GameCommon's tools/build_boy_tp.py) beside the same people on
## the full boy (boy.glb): dressed as HazardPerson dresses them (faceless mask heads), from four sides, then a crowd.
## Prints the triangles shown per dressed person, high and low, and whether the two skeletons' rests match:
##   godot --path . --audio-driver Dummy --fixed-fps 60 --resolution 1280x720 -s res://tests/people_lo_shots.gd -- --out=<dir>
## Needs a window (kept off the screen).

const HIGH := preload("res://models/boy.glb")
const LOW := preload("res://models/boy_tp.glb")
const MASKS := ["mask", "mask_long", "mask_soft", "mask_brow", "mask_square", "inside"]

var out := "user://people_lo_shots"


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.substr(6)
	DirAccess.make_dir_recursive_absolute(out)
	root.position = Vector2i(-3000, 0)
	_run.call_deferred()


func _person(stage: Node3D, model: PackedScene, look_seed: int, at: Vector3, turn: float) -> Figure:
	var man := Figure.new()
	man.model = model
	man.size = 1.4
	man.position = at
	man.rotation.y = turn
	stage.add_child(man)
	HeadShape.add_to(man.rig)
	var chosen := CharacterLook.random(look_seed)
	chosen["face"] = "mannequin"
	var look := CharacterLook.dressed(chosen)
	look["parts"]["head"] = HeadShape.option(MASKS[look_seed % MASKS.size()])
	man.rig.look = look
	man.rig.restyle()
	return man


func _triangles(man: Figure) -> int:
	var count := 0
	for part: MeshInstance3D in man.rig.find_children("*", "MeshInstance3D", true, false):
		if not part.is_visible_in_tree() or part.mesh == null:
			continue
		for s in part.mesh.get_surface_count():
			var arrays := part.mesh.surface_get_arrays(s)
			var index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			count += (index.size() if index.size() > 0 else (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()) / 3
	return count


func _shoot(name: String) -> void:
	for _i in 4:
		await process_frame
	root.get_texture().get_image().save_png(out.path_join(name + ".png"))


func _run() -> void:
	var stage := Node3D.new()
	root.add_child(stage)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50.0, 30.0, 0.0)
	sun.shadow_enabled = true
	stage.add_child(sun)
	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.background_mode = Environment.BG_COLOR
	world.environment.background_color = Color(0.55, 0.72, 0.9)
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color(0.6, 0.6, 0.65)
	stage.add_child(world)
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(60, 60)
	floor_mesh.mesh = plane
	var green := StandardMaterial3D.new()
	green.albedo_color = Color(0.35, 0.55, 0.25)
	floor_mesh.material_override = green
	stage.add_child(floor_mesh)
	var ground := StaticBody3D.new()
	var flat := CollisionShape3D.new()
	flat.shape = WorldBoundaryShape3D.new()
	ground.add_child(flat)
	stage.add_child(ground)
	var camera := Camera3D.new()
	camera.fov = 40.0
	stage.add_child(camera)
	# The rests of the two skeletons (the low one re-exported through Blender)
	var a := HIGH.instantiate()
	var b := LOW.instantiate()
	var sa := a.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var sb := b.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var worst := 0.0
	var missing := 0
	for bone in sa.get_bone_count():
		var other := sb.find_bone(sa.get_bone_name(bone))
		if other < 0:
			missing += 1
			continue
		var ra := sa.get_bone_global_rest(bone)
		var rb := sb.get_bone_global_rest(other)
		worst = maxf(worst, ra.origin.distance_to(rb.origin))
		for k in 3:
			worst = maxf(worst, (ra.basis[k] - rb.basis[k]).length())
	print("bones %d / %d, %d missing, worst rest difference %.5f" % [sa.get_bone_count(), sb.get_bone_count(), missing, worst])
	a.free()
	b.free()
	# Four people, each high (left) beside low (right)
	var pairs := []
	for k in 4:
		var x := (k - 1.5) * 3.2
		pairs.append([_person(stage, HIGH, k * 7 + 1, Vector3(x - 0.55, 0, 0), 0.0), _person(stage, LOW, k * 7 + 1, Vector3(x + 0.55, 0, 0), 0.0)])
	for _i in 10:
		await physics_frame
	for pair: Array in pairs:
		print("dressed person: high %d tris, low %d tris" % [_triangles(pair[0]), _triangles(pair[1])])
	for k in 4:
		var x := (k - 1.5) * 3.2
		# (each pair alone, seen a little round from each side so neither hides the other)
		for j in 4:
			pairs[j][0].visible = j == k
			pairs[j][1].visible = j == k
		for side: Array in [["front", Vector3(0, 0, 1)], ["right", Vector3(1, 0, 0)], ["back", Vector3(0, 0, -1)], ["left", Vector3(-1, 0, 0)]]:
			var middle := Vector3(x, 1.0, 0)
			camera.look_at_from_position(middle + (side[1] as Vector3).rotated(Vector3.UP, 0.4) * 4.2 + Vector3.UP * 0.3, middle)
			await _shoot("pair%d_%s" % [k, side[0]])
		var bones := (pairs[k][0] as Figure).rig.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
		var head_y := (bones.global_transform * bones.get_bone_global_pose(bones.find_bone("head"))).origin.y - 0.08
		camera.look_at_from_position(Vector3(x, head_y + 0.1, 1.5), Vector3(x, head_y, 0))
		await _shoot("pair%d_heads" % k)
	for pair: Array in pairs:
		pair[0].queue_free()
		pair[1].queue_free()
	# A crowd of the low people
	for k in 30:
		var man := _person(stage, LOW, k, Vector3((k % 6 - 2.5) * 1.4, 0, (k / 6 - 2.0) * 1.6), randf() * TAU)
		man.go_to(man.position + Vector3(randf_range(-3, 3), 0, randf_range(-3, 3)))
	for _i in 40:
		await physics_frame
	camera.look_at_from_position(Vector3(0, 6, 12), Vector3(0, 0.8, 0))
	await _shoot("crowd")
	quit()
