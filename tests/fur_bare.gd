extends SceneTree
## Density 0 leaves him bare (the user, 2026-11-02: "I turned down the density but there's still a bunch of little
## spiky fur — that isn't controlled by the length or angle either"): in every one of his models, every point of the
## body's fur out from its root (all but the tail's and the whiskers') must carry its offset from its root, so the fur
## shader can fold it in and lay it by the sliders. Counts the points that could not be (FurLook._SHAPED: a point with
## no offset stays where it is), and prints PASSED or FAILED. Headless:
##   godot --headless --path . --audio-driver Dummy -s res://tests/fur_bare.gd


func _initialize() -> void:
	var paths := ["res://models/raccoon.glb", "res://models/raccoon_lo.glb"]
	for kind: String in FurLook.TYPES:
		if kind != "spiky":
			paths.append("res://models/raccoon_fur_%s.glb" % kind)
	for shape: String in FurLook.SHAPES:
		if shape != "triangle":
			paths.append("res://models/raccoon_shape_%s.glb" % shape)
	var ok := true
	for path: String in paths:
		var scene := (load(path) as PackedScene).instantiate()
		var stuck := 0
		var fur := 0
		for part: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
			for surface in part.mesh.get_surface_count():
				var arrays := part.mesh.surface_get_arrays(surface)
				var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
				var uv2: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2]
				var colours: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
				if uv2.is_empty() or colours.is_empty():
					continue
				for i in uv2.size():
					if uv2[i].y <= 1.0005:
						continue
					var flex := uv2[i].y - 1.001
					var group := int(floor(fposmod(uv2[i].x, 1.0) * 10.0 + 0.25))
					if group > 2 or flex <= 0.01:
						continue
					fur += 1
					var offset := Vector3(uv[i].x, 1.0 - uv[i].y, (colours[i].g - 0.5) * 0.5)
					if offset.length() < 0.0005:
						stuck += 1
		scene.free()
		print("%s: %d fur points, %d that could not fold" % [path.get_file(), fur, stuck])
		ok = ok and stuck == 0 and fur > 0
	print("PASSED" if ok else "FAILED")
	quit()
