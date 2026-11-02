extends SceneTree
## The people in the vehicles fit inside them (CarRider): each kind with every seat filled, every rider's skinned
## surface measured against its vehicle's body (its closed shell: build_vehicles.py prism) by rays from each point (to its triangles) up
## to the roof, down to the floor and out to the nearer side. Any point with no shell over it, under it or beside it
## is outside (through the roof, the floor or a door). Headless:
##   godot --headless --path . --audio-driver Dummy --fixed-fps 60 -s res://tests/rider_fit.gd

## Least room kept (m) between a rider and the roof / doors; the floor may be touched (feet on it).
const ROOM := 0.01

var failures: Array[String] = []


func _initialize() -> void:
	var level: Node3D = load("res://scenes/playground.tscn").instantiate()
	root.add_child(level)
	_run.call_deferred(level)


func _check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)
	if not ok:
		failures.append(what)


func _run(level: Node3D) -> void:
	for _i in 5:
		await physics_frame
	var x := 0.0
	for kind: StringName in HazardCar.KINDS:
		var car := HazardCar.new()
		car.kind = kind
		car.route = PackedVector3Array([Vector3(x, 0.05, -60.0), Vector3(x, 0.05, -80.0)])
		# (every seat taken)
		car.seat_chance = 1.0
		level.add_child(car)
		car.set_physics_process(false)
		x += 6.0
		for _i in 20:
			await process_frame
		_measure(car)
		car.queue_free()
	print("PASSED" if failures.is_empty() else "FAILED: " + ", ".join(failures))
	quit()


func _measure(car: HazardCar) -> void:
	var body: MeshInstance3D = car.find_child("%s_body" % car.kind, true, false)
	var tris := body.mesh.get_faces()
	var to_body := body.global_transform.affine_inverse()
	# (the seats: a point inside one, crossing its faces an odd number of times going up, is through it)
	var chairs: MeshInstance3D = car.find_child("%s_seats" % car.kind, true, false)
	var chair_tris := chairs.mesh.get_faces() if chairs else PackedVector3Array()
	var to_chairs := chairs.global_transform.affine_inverse() if chairs else Transform3D.IDENTITY
	var in_seat := 0
	var riders: Array = car._riders
	var worst := {"roof": INF, "floor": INF, "side": INF}
	var outside := 0
	var points := 0
	for rider: CarRider in riders:
		for p in _skinned(rider.rig):
			var local := to_body * p
			points += 1
			# (sunk into the cushion under them is let by: only above it, into a seat's back, counts)
			var at_chair := to_chairs * p
			if chairs and at_chair.y > rider.seat.position.y + 0.01 and _crossings(chair_tris, at_chair, Vector3.UP) % 2 == 1:
				in_seat += 1
				if in_seat <= 3:
					print("  into a seat at %s (seat %s)" % [at_chair, rider.seat.name])
			var up := _ray(tris, local, Vector3.UP)
			var down := _ray(tris, local, Vector3.DOWN)
			var side := _ray(tris, local, Vector3(signf(local.x) if local.x != 0.0 else 1.0, 0.0, 0.0))
			if up == INF or down == INF or side == INF:
				outside += 1
				if outside <= 4:
					print("  outside at %s (seat %s; no %s)" % [local, rider.seat.name, ("roof " if up == INF else "") + ("floor " if down == INF else "") + ("side" if side == INF else "")])
				continue
			worst["roof"] = minf(worst["roof"], up)
			worst["floor"] = minf(worst["floor"], down)
			worst["side"] = minf(worst["side"], side)
	_check(not riders.is_empty() and points > 0 and outside == 0 and in_seat == 0 and worst["roof"] >= ROOM and worst["side"] >= ROOM,
		"%s: %d people, %d points, outside: %d, through a seat's back: %d; least room to the roof %.3f m, to a side %.3f m, to the floor %.3f m" % [
			car.kind, riders.size(), points, outside, in_seat, worst["roof"], worst["side"], worst["floor"]])


## How many triangles a ray from `from` along `way` goes through.
func _crossings(tris: PackedVector3Array, from: Vector3, way: Vector3) -> int:
	var count := 0
	for i in range(0, tris.size(), 3):
		if Geometry3D.ray_intersects_triangle(from, way, tris[i], tris[i + 1], tris[i + 2]) != null:
			count += 1
	return count


## How far along `way` from `from` the nearest triangle is (INF: none).
func _ray(tris: PackedVector3Array, from: Vector3, way: Vector3) -> float:
	var best := INF
	for i in range(0, tris.size(), 3):
		var hit: Variant = Geometry3D.ray_intersects_triangle(from, way, tris[i], tris[i + 1], tris[i + 2])
		if hit != null:
			best = minf(best, from.distance_to(hit))
	return best


## Every few points of the rig's meshes, where they are drawn now (a skinned one skinned here, as the GPU would).
func _skinned(rig: Node3D) -> PackedVector3Array:
	var out := PackedVector3Array()
	for mesh: MeshInstance3D in rig.find_children("*", "MeshInstance3D", true, false):
		if not mesh.is_visible_in_tree() or mesh.mesh == null:
			continue
		# (a piece held by a bone, a hat or a mask head: where it is drawn)
		if mesh.skin == null:
			var faces := mesh.mesh.get_faces()
			for v in range(0, faces.size(), 3):
				out.append(mesh.global_transform * faces[v])
			continue
		var skeleton := mesh.get_node_or_null(mesh.skeleton) as Skeleton3D
		if skeleton == null:
			continue
		var skin := mesh.skin
		var poses: Array[Transform3D] = []
		for b in skin.get_bind_count():
			var bone := skin.get_bind_bone(b)
			if bone < 0:
				bone = skeleton.find_bone(skin.get_bind_name(b))
			poses.append(skeleton.global_transform * skeleton.get_bone_global_pose(bone) * skin.get_bind_pose(b))
		for s in mesh.mesh.get_surface_count():
			var arrays := mesh.mesh.surface_get_arrays(s)
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
			var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
			if bones.is_empty():
				continue
			var per := bones.size() / verts.size()
			for v in range(0, verts.size(), 3):
				var at := Vector3.ZERO
				for k in per:
					var w := weights[v * per + k]
					if w > 0.0:
						at += (poses[bones[v * per + k]] * verts[v]) * w
				out.append(at)
	return out
