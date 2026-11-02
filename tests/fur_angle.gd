extends SceneTree
## Angle swings the fringes on his belly and hips (the user, 2026-11-02: "the angle still doesn't seem to move the ones
## hanging on his belly"): for the body's ruff and tuft tips (regions hips and chest), the mean of how far each tip
## stands out from his body (along the level way out from the body's line) and how far down it hangs, at rest, with
## the fur shader's angle step (FurLook._SHAPED, done here on the CPU) at Angle -0.9, 0 and 0.9. Prints PASSED if
## standing out clearly gains on hanging down and laid back clearly loses. Headless:
##   godot --headless --path . --audio-driver Dummy -s res://tests/fur_angle.gd


func _laid(now: Vector3, axis: Vector3, angle: float) -> Vector3:
	# (FurLook._SHAPED's angle step, as it is there)
	var length := now.length()
	var dir := now.normalized()
	if absf(angle) > 0.0001:
		var c := dir.dot(axis)
		var side := dir - axis * c
		var s := side.length()
		if s > 0.001:
			var c2 := clampf(c + angle, FurLook.ANGLE_LEAST, FurLook.ANGLE_MOST)
			dir = axis * c2 + side / s * sqrt(1.0 - c2 * c2)
	return dir * length


func _initialize() -> void:
	var scene := (load("res://models/raccoon.glb") as PackedScene).instantiate()
	var skeleton := scene.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var tips: Array = []
	for part: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
		for surface in part.mesh.get_surface_count():
			var arrays := part.mesh.surface_get_arrays(surface)
			var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
			var uv2: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2]
			var colours: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
			if uv2.is_empty():
				continue
			for i in uv2.size():
				var flex := uv2[i].y - 1.001
				var region := int(uv2[i].x + 0.5)
				var group := int(floor(fposmod(uv2[i].x, 1.0) * 10.0 + 0.25))
				if flex < 0.99 or group != 0 or region > 1:
					continue
				var now := Vector3(uv[i].x, 1.0 - uv[i].y, (colours[i].g - 0.5) * 0.5)
				tips.append([points[i] - now, now, region])
	var ok := true
	var results := {}
	for angle: float in [-0.9, 0.0, 0.9]:
		var out_sum := 0.0
		var down_sum := 0.0
		for tip: Array in tips:
			var root: Vector3 = tip[0]
			var bone := skeleton.find_bone("hips" if tip[2] == 0 else "chest")
			var middle := skeleton.get_bone_global_rest(bone).origin
			var away := root - middle
			away.y = 0.0
			away = away.normalized()
			var off := _laid(tip[1], FurLook.REGION_AXES[tip[2]], angle)
			out_sum += off.dot(away)
			down_sum += -off.y
		results[angle] = [out_sum / tips.size(), down_sum / tips.size()]
		print("angle %+.1f: %d tips, mean out %.3f m, mean down %.3f m" % [angle, tips.size(), results[angle][0], results[angle][1]])
	ok = results[-0.9][0] > results[0.0][0] + 0.01 and results[0.9][0] < results[0.0][0] - 0.01
	ok = ok and results[0.9][1] > results[0.0][1] + 0.005
	print("PASSED" if ok else "FAILED")
	scene.free()
	quit()
