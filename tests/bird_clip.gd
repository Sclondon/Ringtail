extends SceneTree
## Measures how far the crow's and the owl's folded wings go into their bodies: every wing point (but those at
## the shoulder joints) is tested against the body's ellipsoids (as tools/build_birds.py makes them). Prints the
## deepest point in mm and PASSED/FAILED (over 4 mm in counts as a clip). Headless:
##   godot --headless --path . --audio-driver Dummy -s res://tests/bird_clip.gd

## [centre, radii, tilt] of each body ellipsoid, in the model's space (build_birds.py: crow(), owl()).
const BODIES := {
	&"crow": [[Vector3(0, 0.23, -0.01), Vector3(0.078, 0.082, 0.15), 0.38], [Vector3(0, 0.265, 0.06), Vector3(0.07, 0.078, 0.07), 0.0]],
	&"owl": [[Vector3(0, 0.25, -0.01), Vector3(0.135, 0.19, 0.12), 0.12], [Vector3(0, 0.24, 0.035), Vector3(0.12, 0.17, 0.09), 0.0],
		[Vector3(0, 0.13, 0.02), Vector3(0.11, 0.08, 0.09), 0.0]],
}


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var failed := false
	for kind: StringName in BODIES:
		var bird := BirdBody.make(kind)
		root.add_child(bird)
		bird.fold = 1.0
		for _i in 30:
			await process_frame
		var deepest := 0.0
		var where := ""
		# (the shoulders: where each wing joins the body, it is meant to be in it)
		var joints: Array[Vector3] = []
		for shoulder: Node3D in bird.find_children("*_wing_?", "Node3D", true, false):
			joints.append(bird.global_transform.affine_inverse() * shoulder.global_position)
		for part: MeshInstance3D in bird.find_children("*_wing_*", "MeshInstance3D", true, false):
			var to_model := bird.global_transform.affine_inverse() * part.global_transform
			for surface in part.mesh.get_surface_count():
				var points: PackedVector3Array = part.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
				for point in points:
					var p := to_model * point
					if joints.any(func(j: Vector3) -> bool: return j.distance_to(p) < 0.035):
						continue
					for body: Array in BODIES[kind]:
						var depth := _depth(p, body[0], body[1], body[2])
						if depth > deepest:
							deepest = depth
							where = "%s at %s" % [part.name, p]
		print("%s folded: deepest wing point %.1f mm into the body (%s)" % [kind, deepest * 1000.0, where])
		failed = failed or deepest > 0.004
		bird.queue_free()
	print("FAILED" if failed else "PASSED")
	quit()


## How far inside the ellipsoid `p` is (m, roughly: along its smallest radius), 0 outside.
func _depth(p: Vector3, centre: Vector3, radii: Vector3, tilt: float) -> float:
	var q := p - centre
	# (into the ellipsoid's own frame: undo its pitch)
	var c := cos(-tilt)
	var s := sin(-tilt)
	q = Vector3(q.x, q.y * c + q.z * s, -q.y * s + q.z * c)
	var r := Vector3(q.x / radii.x, q.y / radii.y, q.z / radii.z).length()
	return maxf(0.0, (1.0 - r) * minf(radii.x, minf(radii.y, radii.z)))
