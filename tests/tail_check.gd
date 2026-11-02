extends SceneTree
## Tail length and thickness (the model editor's): Length should only lengthen the tail, Thickness only fatten it,
## and neither should change which way it points (the user, 2026-11-02: "the tail length and thickness do not work
## correctly — both change both aspects and the tail angle"). Measures the tail's bones standing still, prints
## PASSED or FAILED. Headless:
##   godot --headless --path . --audio-driver Dummy --fixed-fps 60 -s res://tests/tail_check.gd


func _initialize() -> void:
	_run.call_deferred()


func _measure(length: float, thickness: float) -> Array:
	var stand := FurEditor.Stand.new()
	var rig := RaccoonRig.new()
	rig.model = load("res://models/raccoon.glb")
	rig.key_poses = false
	rig.cap_hand = false
	rig.dusty = false
	stand.add_child(rig)
	root.add_child(stand)
	rig.tail_length = length
	rig.tail_thickness = thickness
	for _i in 90:
		await physics_frame
	var skeleton: Skeleton3D = rig._skeleton
	var points := PackedVector3Array()
	for k in 6:
		points.append(skeleton.get_bone_global_pose(skeleton.find_bone("tail_%d" % k)).origin)
	var chain := 0.0
	for k in 5:
		chain += points[k].distance_to(points[k + 1])
	var way := (points[5] - points[0]).normalized()
	# (the middle bone's scale: the same every way, or none; its thickness is the fur shader's, not the bones')
	var middle := skeleton.get_bone_global_pose(skeleton.find_bone("tail_2")).basis
	stand.queue_free()
	await process_frame
	return [chain, way, middle.get_scale()]


func _run() -> void:
	var plain: Array = await _measure(1.0, 1.0)
	var long: Array = await _measure(1.5, 1.0)
	var thick: Array = await _measure(1.0, 1.8)
	var ok := true
	for named: String in ["plain", "long", "thick"]:
		var got: Array = {"plain": plain, "long": long, "thick": thick}[named]
		print("%s: chain %.3f m, pointing %s (%.1f deg from plain), scale %s" % [named, got[0], got[1],
				rad_to_deg((got[1] as Vector3).angle_to(plain[1])), got[2]])
	var long_ratio: float = long[0] / plain[0]
	var thick_ratio: float = thick[0] / plain[0]
	ok = ok and absf(long_ratio - 1.5) < 0.08 and absf(thick_ratio - 1.0) < 0.05
	ok = ok and rad_to_deg((long[1] as Vector3).angle_to(plain[1])) < 4.0 and rad_to_deg((thick[1] as Vector3).angle_to(plain[1])) < 4.0
	print("length x%.2f for Length 1.5, x%.2f for Thickness 1.8" % [long_ratio, thick_ratio])
	print("PASSED" if ok else "FAILED")
	quit()
