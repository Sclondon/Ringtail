class_name PlantMesh
extends RefCounted
## What FlowerGen and BrambleGen build their meshes with: triangles, tubes along a line, leaves and petals, every vertex
## coloured and carrying in UV.y how far up the plant it is (0 at the foot to 1 at the top: how much it sways, PlantLook).

var tool := SurfaceTool.new()
## The plant's height, for UV.y.
var top := 1.0
var triangles := 0


func _init(height := 1.0) -> void:
	top = maxf(height, 0.01)
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)


func tri(a: Vector3, b: Vector3, c: Vector3, ca: Color, cb := Color(-1, 0, 0), cc := Color(-1, 0, 0)) -> void:
	if cb.r < 0.0:
		cb = ca
	if cc.r < 0.0:
		cc = ca
	var normal := (b - a).cross(c - a)
	if normal.length() < 1e-9:
		return
	normal = normal.normalized()
	# (lit as if facing up a little more than it does: a thin leaf reads soft, not black from below)
	normal = (normal * signf(normal.y + 0.001) + Vector3.UP * 0.4).normalized()
	for pair: Array in [[a, ca], [b, cb], [c, cc]]:
		var p: Vector3 = pair[0]
		tool.set_color(pair[1])
		tool.set_normal(normal)
		tool.set_uv(Vector2(0.0, clampf(p.y / top, 0.0, 1.0)))
		tool.add_vertex(p)
	triangles += 1


func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, ca: Color, cb := Color(-1, 0, 0)) -> void:
	if cb.r < 0.0:
		cb = ca
	tri(a, b, c, ca, ca, cb)
	tri(a, c, d, ca, cb, cb)


## A tube through `points` (radius `radii` at each), `sides` round, from colour `from` at its start to `to` at its end.
## Its end is closed to a point when the last radius is 0.
func tube(points: Array, radii: Array, sides: int, from: Color, to: Color) -> void:
	var rings: Array = []
	for k in points.size():
		var p: Vector3 = points[k]
		var along: Vector3 = ((points[mini(k + 1, points.size() - 1)] as Vector3) - (points[maxi(k - 1, 0)] as Vector3)).normalized()
		var a := along.cross(Vector3.UP if absf(along.y) < 0.95 else Vector3.RIGHT).normalized()
		var b := along.cross(a).normalized()
		var ring: Array[Vector3] = []
		for s in sides:
			var t := TAU * s / sides
			ring.append(p + (a * cos(t) + b * sin(t)) * float(radii[k]))
		rings.append(ring)
	for k in points.size() - 1:
		var c0 := from.lerp(to, float(k) / (points.size() - 1))
		var c1 := from.lerp(to, float(k + 1) / (points.size() - 1))
		for s in sides:
			var s2 := (s + 1) % sides
			if float(radii[k + 1]) <= 0.0:
				tri(rings[k][s], rings[k][s2], points[k + 1], c0, c0, c1)
			else:
				quad(rings[k][s], rings[k][s2], rings[k + 1][s2], rings[k + 1][s], c0, c1)


## A flat blade from `base` along `dir` (unit), its face towards `facing` (unit, across it), `length` long and at most
## `width` wide, outlined by `profile` (widths 0..1 at even steps from base to tip), folded a little along its middle
## (`fold`, metres up at the edges) and bent over `droop` (metres down at the tip). Teeth along the edge (`teeth` per
## side, 0 none) for a serrated leaf. From colour `inner` at its middle to `outer` at its edges.
func blade(base: Vector3, dir: Vector3, facing: Vector3, length: float, width: float, profile: Array, inner: Color,
		outer: Color, fold := 0.0, droop := 0.0, teeth := 0) -> void:
	var side := dir.cross(facing).normalized()
	var up := side.cross(dir).normalized()
	var steps := profile.size() - 1
	var mids: Array[Vector3] = []
	var lefts: Array[Vector3] = []
	var rights: Array[Vector3] = []
	for k in steps + 1:
		var t := float(k) / steps
		var mid := base + dir * length * t - up * droop * t * t
		var w := float(profile[k]) * width * 0.5
		# (a tooth: every other point along the edge pushed out a little)
		if teeth > 0 and k > 0 and k < steps:
			w *= 1.0 + 0.18 * float(k % 2)
		mids.append(mid)
		lefts.append(mid - side * w + up * fold)
		rights.append(mid + side * w + up * fold)
	for k in steps:
		_strip(lefts[k], mids[k], mids[k + 1], lefts[k + 1], outer, inner)
		_strip(mids[k], rights[k], rights[k + 1], mids[k + 1], inner, outer)


func _strip(a: Vector3, b: Vector3, c: Vector3, d: Vector3, first: Color, second: Color) -> void:
	# (a and d on one edge, b and c on the other; a degenerate edge gives one triangle)
	if a.distance_to(d) < 1e-5:
		tri(a, b, c, first, second, second)
	elif b.distance_to(c) < 1e-5:
		tri(a, b, d, first, second, first)
	else:
		tri(a, b, c, first, second, second)
		tri(a, c, d, first, second, first)


## A little lumpy ball (a berry, a bud, a flower's middle): an octahedron, `radius`, squashed by `squash` along Y.
func ball(at: Vector3, radius: float, colour: Color, squash := 1.0, rng: RandomNumberGenerator = null) -> void:
	var points: Array[Vector3] = [Vector3.UP * squash, Vector3.DOWN * squash, Vector3.RIGHT, Vector3.LEFT, Vector3.FORWARD, Vector3.BACK]
	for k in points.size():
		var bump := rng.randf_range(0.85, 1.15) if rng else 1.0
		points[k] = at + points[k] * radius * bump
	var dark := colour.darkened(0.25)
	for face: Array in [[0, 2, 4], [0, 4, 3], [0, 3, 5], [0, 5, 2], [1, 4, 2], [1, 3, 4], [1, 5, 3], [1, 2, 5]]:
		tri(points[face[0]], points[face[1]], points[face[2]], colour if face[0] == 0 else dark, colour, colour)


func commit() -> ArrayMesh:
	tool.index()
	var made := tool.commit()
	if made.get_surface_count() > 0:
		made.surface_set_material(0, PlantLook.shared())
	return made
