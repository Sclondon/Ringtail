class_name PointPerches
extends RefCounted
## The points he can stand on one hand on (PointStand; the user, 2026-11-02: "you need to be able to handstand on one
## hand on the top of pointy things like trees and telephone poles"): the tops of the telephone poles and the
## chimney (the world model's climb_ meshes named for poles or a chimney: the middle of each top), and the tips of
## the trees (each tree body's highest point, over its trunk).
##
##   PointPerches.find(world)          # once the world model and its trees are in
##   PointPerches.nearest(at, reach)   # the point nearest `at` across the ground within `reach`, or Vector3.INF

## The points, in the world.
static var points := PackedVector3Array()


static func find(world: Node) -> void:
	points.clear()
	for node in world.get_tree().get_nodes_in_group(&"climbable"):
		if not world.is_ancestor_of(node):
			continue
		if node is MeshInstance3D:
			var called := String(node.name)
			if called.contains("pole") or called.contains("chimney"):
				_tops(node as MeshInstance3D)
		elif node is Node3D:
			_tree_tip(node as Node3D)


## The point nearest `at` across the ground within `reach` (m), or Vector3.INF.
static func nearest(at: Vector3, reach: float) -> Vector3:
	var best := Vector3.INF
	var nearest_d := reach
	for p in points:
		var d := Vector2(p.x - at.x, p.z - at.z).length()
		if d < nearest_d:
			nearest_d = d
			best = p
	return best


## The tops of the upright things in `mesh` (many poles may be one mesh): its points gathered by metre squares, each
## square's highest ring of points, and their middle; squares close together (one pole across two) taken as one.
static func _tops(mesh: MeshInstance3D) -> void:
	if mesh.mesh == null:
		return
	var to_world := mesh.global_transform
	var highest := {}
	var rings := {}
	for k in mesh.mesh.get_surface_count():
		var verts: PackedVector3Array = mesh.mesh.surface_get_arrays(k)[Mesh.ARRAY_VERTEX]
		for v in verts:
			var p := to_world * v
			var cell := Vector2i(floori(p.x), floori(p.z))
			if not highest.has(cell) or p.y > float(highest[cell]) + 0.02:
				highest[cell] = p.y
				rings[cell] = [p]
			elif p.y > float(highest[cell]) - 0.02:
				(rings[cell] as Array).append(p)
	var found: Array[Vector3] = []
	for cell: Vector2i in rings:
		var middle := Vector3.ZERO
		for p: Vector3 in rings[cell]:
			middle += p
		middle /= (rings[cell] as Array).size()
		# (one pole whose top falls across two squares: the higher half kept, moved to the middle of both)
		var merged := false
		for k in found.size():
			if Vector2(found[k].x - middle.x, found[k].z - middle.z).length() < 0.6:
				var y := maxf(found[k].y, middle.y)
				found[k] = Vector3((found[k].x + middle.x) * 0.5, y, (found[k].z + middle.z) * 0.5)
				merged = true
				break
		if not merged:
			found.append(middle)
	for p in found:
		# (only tops well up off the ground: not the little ends of anything low)
		if p.y - _ground_under(mesh, p) > 2.0:
			points.append(p)


## A tree's tip: over its trunk, at the top of what is drawn of it.
static func _tree_tip(body: Node3D) -> void:
	var top := -INF
	for part: MeshInstance3D in body.find_children("*", "MeshInstance3D", true, false):
		var box := part.global_transform * part.get_aabb()
		top = maxf(top, box.end.y)
	if top > body.global_position.y + 2.0:
		points.append(Vector3(body.global_position.x, top, body.global_position.z))


static func _ground_under(node: Node3D, p: Vector3) -> float:
	var space := node.get_world_3d().direct_space_state
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(p + Vector3.DOWN * 0.5, p + Vector3.DOWN * 40.0, 1))
	return (hit.position as Vector3).y if not hit.is_empty() else p.y - 10.0
