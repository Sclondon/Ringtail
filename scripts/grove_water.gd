class_name GroveWater
extends Node3D
## The grove's water, drawn rather than modelled (the user, 2026-11-02: "the spring and waterfall needs a ton of work
## not just flat texture, it needs to be a small bubbling pond with a real waterfall"): a small spring pool on the
## outcrop, welling up and bubbling (GameCommon's Water and WaterSpring), spilling over its lip in a waterfall
## (Waterfall) into the big pond, which gets the same lively water look. From the town's markers: `spring_pool` (the
## pool's surface middle; scale x its radius, y its depth), `waterfall_top`, `waterfall_bottom`; without them, from
## the older `spring` marker and the pond (`pool`). The modelled `nocol_spring_water` it replaces is hidden.
## Colours and sizes are Claude's picks.
##
##   GroveWater.place(world, markers)

## The pond's look: clear green-blue shallows going to a deep fir-green, livelier lines and glints, a wider foam rim.
const POND_SHALLOW := Color(0.3, 0.62, 0.6)
const POND_DEEP := Color(0.04, 0.17, 0.2)
## The spring pool's: brighter and clearer, it is shallow and fresh.
const SPRING_SHALLOW := Color(0.42, 0.78, 0.8)
const SPRING_DEEP := Color(0.1, 0.36, 0.42)

var spring_water: Water
var spring: WaterSpring
var falls: Waterfall
var pond: Pool


static func place(world: Node3D, markers: Dictionary) -> GroveWater:
	var made := GroveWater.new()
	made.name = "GroveWater"
	world.add_child(made)
	made._build(world, markers)
	return made


func _build(world: Node3D, markers: Dictionary) -> void:
	pond = _pond(world, markers)
	if pond:
		_liven(pond.water, POND_SHALLOW, POND_DEEP)
	# The spring pool
	var middle := Vector3.INF
	var radius := 0.7
	var depth := 0.45
	if markers.has("spring_pool"):
		var mark: Transform3D = markers["spring_pool"]
		middle = mark.origin
		var size := mark.basis.get_scale()
		radius = size.x if size.x > 0.05 else radius
		depth = size.y if size.y > 0.05 else depth
	elif markers.has("spring"):
		middle = (markers["spring"] as Transform3D).origin + Vector3.UP * 0.04
		depth = 0.12
	if middle == Vector3.INF:
		return
	_hide_modelled(world)
	spring_water = Water.new()
	spring_water.size = Vector3(radius * 2.0, depth, radius * 2.0)
	spring_water.position = middle
	spring_water.sides = false
	spring_water.underwater = false
	spring_water.swell_height = 0.008
	spring_water.foam_width = 0.12
	spring_water.depth_range = maxf(depth * 1.5, 0.3)
	spring_water.banded = Settings.world_banded
	add_child(spring_water)
	_liven(spring_water, SPRING_SHALLOW, SPRING_DEEP)
	spring = WaterSpring.new()
	spring.water = spring_water
	spring.reach = radius * 0.45
	spring.strength = 1.2
	spring_water.add_child(spring)
	spring.position = Vector3.DOWN * depth * 0.85
	# The falls, from its lip down into the pond
	var top := Vector3.INF
	var bottom := Vector3.INF
	if markers.has("waterfall_top") and markers.has("waterfall_bottom"):
		top = (markers["waterfall_top"] as Transform3D).origin
		bottom = (markers["waterfall_bottom"] as Transform3D).origin
	elif pond:
		# (no markers for it: out from the pool towards the pond till the rock it sits on falls away)
		var way := pond.global_position - middle
		way.y = 0.0
		way = way.normalized()
		var edge := _edge(middle, way, radius)
		top = edge[0]
		bottom = edge[1]
	if top == Vector3.INF:
		return
	falls = Waterfall.new()
	falls.top = top
	falls.bottom = bottom
	falls.width = clampf(radius * 0.6, 0.45, 1.0)
	# (the water runs from the pool's edge to the lip as the flat top of the same sheet)
	falls.lip = maxf(0.35, Vector2(top.x - middle.x, top.z - middle.z).length() - radius * 0.7)
	falls.water_colour = SPRING_SHALLOW.lerp(Color.WHITE, 0.15)
	falls.pool = pond.water if pond else null
	# (placed before it is added: it builds itself round where it stands)
	falls.position = top - global_position
	add_child(falls)


## Where the water going out from `middle` along `way` goes over the edge of what it lies on, and where it comes down:
## steps out, looking down, till the ground under it is well below the pool; it lands on the pond's surface if that
## is there, else on the ground.
func _edge(middle: Vector3, way: Vector3, radius: float) -> Array[Vector3]:
	var space := get_world_3d().direct_space_state
	var lip := middle + way * (radius + 0.3)
	var step := 0.1
	for k in 80:
		var at := middle + way * (radius + step * k)
		var query := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 0.5, at + Vector3.DOWN * 12.0, 1)
		var hit := space.intersect_ray(query)
		var ground := (hit.position as Vector3).y if not hit.is_empty() else middle.y - 12.0
		if ground < middle.y - 0.8:
			# (over the edge: the lip just back from here, the foot a little out from the face)
			lip = middle + way * (radius + step * maxi(k - 1, 0))
			var foot := at + way * 0.35
			var land := ground
			if pond and pond.depth_at(Vector3(foot.x, pond.surface_y() - 0.01, foot.z)) > 0.0:
				land = maxf(ground, pond.surface_y())
			return [Vector3(lip.x, middle.y, lip.z), Vector3(foot.x, land, foot.z)]
	return [Vector3(lip.x, middle.y, lip.z), Vector3(lip.x, middle.y - 2.0, lip.z) + way * 0.4]


## The pond: the Pool at the `pool` marker (else the one nearest the grove's heart).
func _pond(world: Node3D, markers: Dictionary) -> Pool:
	var near: Vector3 = (markers["pool"] as Transform3D).origin if markers.has("pool") else \
		((markers["grove_heart"] as Transform3D).origin if markers.has("grove_heart") else Vector3.ZERO)
	var best: Pool
	for node in world.get_children():
		if node is Pool and (best == null or (node as Pool).global_position.distance_to(near) < best.global_position.distance_to(near)):
			best = node
	return best


## The livelier look: its colours, more lines and glints, a wider ragged rim of foam, light on its floor.
func _liven(water: Water, shallow: Color, deep: Color) -> void:
	water.shallow = shallow
	water.deep = deep
	water.lines = 0.6
	water.line_size = 0.9
	water.glint = 3.5
	water.glint_size = 0.08
	water.foam_width = maxf(water.foam_width, 0.2)
	water.foam_ragged = 0.75
	water.caustics = 0.65


## The modelled water the town once drew for the spring (flat faces): hidden now this draws it.
func _hide_modelled(world: Node3D) -> void:
	for mesh: MeshInstance3D in world.find_children("nocol_spring_water*", "MeshInstance3D", true, false):
		mesh.visible = false
