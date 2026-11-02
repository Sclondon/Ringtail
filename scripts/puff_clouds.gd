class_name PuffClouds
extends Node3D
## A sky of puffy cumulus in the Daughter Of The Wind look, for a game that stays on the ground: heaps of soft puffs
## with a flat base, lit in two or three flat tones as one mass, their rims feathered, some with painted curls
## (Okami / Wind Waker), a silver lining against the sun. A ring of heaps round the middle of the scene and a few
## overhead, all one MultiMesh (one draw), turning slowly round the middle so the sky drifts and never runs out.
##
##   var clouds := PuffClouds.add_to(level, sun)       # sun: the scene's DirectionalLight3D (or null)
##
## Taken from Daughter Of The Wind (scripts/cloud_manager.gd `_grow_cloud`, `_make_noise`; shaders/cloud_puff),
## 2026-11-01, without its streaming cells, cloud sea, cirrus, stirring or air queries: those belong to flying.

const PuffShader := preload("res://shaders/puff_cloud.gdshader")

## How many heaps stand in the ring, how far out from the middle (m), and how high their flat bases are (m).
@export var ring_count := 11
@export var ring_distance := Vector2(130.0, 260.0)
@export var ring_height := Vector2(45.0, 90.0)
## How many heaps drift overhead, how far out at most, and how high.
@export var overhead_count := 3
@export var overhead_distance := 90.0
@export var overhead_height := Vector2(95.0, 125.0)
## A heap's half width (m), and its puffs' radii (m).
@export var size := Vector2(22.0, 46.0)
@export var puff := Vector2(8.0, 16.0)
## Height of a heap as a share of its half width.
@export var tall := 0.95
## Most puffs in one heap, and how many little tufts sit round its edge.
@export var max_puffs := 40
@export var tufts := 7
## How fast the whole sky turns round the middle (radians a second): the drift.
@export var drift := 0.004
@export var seed := 7
## The sphere each puff is drawn from: segments round and rings up.
@export var sphere := Vector2i(18, 10)
## How much of the painted curls (0 none).
@export_range(0.0, 1.0) var curls := 1.0
## Colours: the lit side, the shade, the far haze, the silver lining. `add_to` warms the lit side and the lining
## with the sun's own colour.
@export var lit_color := Color(1.0, 0.98, 0.94)
@export var shade_color := Color(0.62, 0.7, 0.84)
@export var haze_color := Color(0.8, 0.88, 0.95)
@export var rim_color := Color(1.0, 0.95, 0.85)
@export var haze_distance := 900.0
## Where the light comes from (towards the sun); `add_to` takes it from the sun.
@export var sun_dir := Vector3(0.3, 0.8, 0.5)

var material: ShaderMaterial
var puffs := 0
var _node: MultiMeshInstance3D


## Puts a sky of clouds over `parent`, lit by `sun` (a DirectionalLight3D; null keeps the defaults).
static func add_to(parent: Node, sun: DirectionalLight3D = null) -> PuffClouds:
	var clouds := PuffClouds.new()
	if sun:
		clouds.sun_dir = (sun.global_basis.z if sun.is_inside_tree() else sun.basis.z).normalized()
		var tint := sun.light_color
		clouds.lit_color = Color(1.0, 0.98, 0.94).lerp(tint, 0.45)
		clouds.rim_color = Color(1.0, 0.95, 0.85).lerp(tint, 0.6)
		# (a low sun: the shade goes cooler and the haze warmer, as at dusk)
		var low := 1.0 - clampf(clouds.sun_dir.y / 0.6, 0.0, 1.0)
		clouds.shade_color = Color(0.62, 0.7, 0.84).lerp(Color(0.52, 0.5, 0.7), low)
		clouds.haze_color = Color(0.8, 0.88, 0.95).lerp(Color(0.92, 0.72, 0.68), low * 0.7)
	parent.add_child(clouds)
	return clouds


func _ready() -> void:
	material = ShaderMaterial.new()
	material.shader = PuffShader
	material.set_shader_parameter(&"noise_tex", _make_noise())
	material.set_shader_parameter(&"sun_dir", sun_dir.normalized())
	material.set_shader_parameter(&"lit_color", lit_color)
	material.set_shader_parameter(&"shade_color", shade_color)
	material.set_shader_parameter(&"haze_color", haze_color)
	material.set_shader_parameter(&"rim_color", rim_color)
	material.set_shader_parameter(&"haze_distance", haze_distance)
	material.set_shader_parameter(&"curls", curls)
	# (nothing streams in or out here: keep them all, out past the ring)
	material.set_shader_parameter(&"fade_start", ring_distance.y * 4.0)
	material.set_shader_parameter(&"fade_end", ring_distance.y * 4.5)
	build()


func _process(delta: float) -> void:
	rotation.y = fposmod(rotation.y + drift * delta, TAU)


## (Re)grows every heap from `seed`.
func build() -> void:
	if _node:
		_node.queue_free()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var transforms: Array = []
	var customs: Array = []
	var colors: Array = []
	for k in ring_count:
		var a := TAU * (k + rng.randf_range(-0.3, 0.3)) / maxf(ring_count, 1)
		var out := rng.randf_range(ring_distance.x, ring_distance.y)
		_grow(Vector3(cos(a) * out, rng.randf_range(ring_height.x, ring_height.y), sin(a) * out), rng, transforms, customs, colors)
	for k in overhead_count:
		var a := rng.randf() * TAU
		var out := sqrt(rng.randf()) * overhead_distance
		_grow(Vector3(cos(a) * out, rng.randf_range(overhead_height.x, overhead_height.y), sin(a) * out), rng, transforms, customs, colors)
	puffs = transforms.size()
	if transforms.is_empty():
		return
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.radial_segments = sphere.x
	mesh.rings = sphere.y
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	mm.mesh = mesh
	mm.instance_count = transforms.size()
	for i in transforms.size():
		mm.set_instance_transform(i, transforms[i])
		mm.set_instance_color(i, colors[i])
		mm.set_instance_custom_data(i, customs[i])
	_node = MultiMeshInstance3D.new()
	_node.multimesh = mm
	_node.material_override = material
	_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# (the shader swells the spheres: give the culling room)
	_node.extra_cull_margin = puff.y * 0.6
	add_child(_node)


## One heap with its flat base at `foot`: columns of puffs on its footprint, tall in the middle and low at the rim
## like a dome, each column climbing in smaller puffs leaning a little; then tufts round its edge.
## (Daughter Of The Wind's `_grow_cloud`, the cumulus layer, without the anvil.)
func _grow(foot: Vector3, rng: RandomNumberGenerator, transforms: Array, customs: Array, colors: Array) -> void:
	var half := rng.randf_range(size.x, size.y)
	var rx := half
	var rz := half * rng.randf_range(0.55, 1.0)
	var turn := rng.randf() * TAU
	var base_y := foot.y
	var height := half * tall * rng.randf_range(0.7, 1.2)
	var core := foot + Vector3.UP * height * 0.3
	var mean_puff := (puff.x + puff.y) * 0.5
	var columns := clampi(int(rx * rz / (mean_puff * mean_puff) * 1.15), 5, 26)
	var first := transforms.size()
	var made := 0
	for c in columns:
		var out := sqrt(rng.randf())
		var ang := rng.randf() * TAU
		var spot := Vector2(cos(ang) * out * rx, sin(ang) * out * rz).rotated(turn)
		var r := lerpf(puff.y, puff.x, out) * rng.randf_range(0.8, 1.1)
		var column_top := height * (1.0 - out * out) * rng.randf_range(0.55, 1.0)
		var y := base_y + r * 0.5
		var lean := Vector2.ZERO
		while true:
			var at := Vector3(foot.x + spot.x + lean.x, y, foot.z + spot.y + lean.y)
			var cut := clampf((base_y - y) / r, -2.0, 1.0)
			var share := clampf((y - base_y) / maxf(height, 1.0), 0.0, 1.0)
			var from_core := (at - core).normalized()
			transforms.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(r, r, r)), at))
			customs.append(Color(rng.randf(), cut, share, 0.0))
			colors.append(Color(from_core.x * 0.5 + 0.5, from_core.y * 0.5 + 0.5, from_core.z * 0.5 + 0.5, 1.0))
			made += 1
			y += r * rng.randf_range(0.75, 1.0)
			r *= rng.randf_range(0.8, 0.93)
			lean += Vector2(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0)) * r * 0.3
			if y > base_y + column_top or made >= max_puffs:
				break
		if made >= max_puffs:
			break
	# The tufts: tiny puffs just proud of the heap's outer puffs, mostly off to the sides, never under its base.
	for t in tufts:
		var host: Transform3D = transforms[first + rng.randi() % made]
		var host_r := host.basis.get_scale()
		var out_dir := (host.origin - core).normalized() + Vector3(rng.randf_range(-1.0, 1.0), rng.randf_range(-0.2, 1.0), rng.randf_range(-1.0, 1.0)) * 0.9
		out_dir.y = absf(out_dir.y * 0.45)
		out_dir = out_dir.normalized()
		var r := clampf(host_r.x * rng.randf_range(0.2, 0.36), puff.x * 0.2, puff.y * 0.6)
		var at := host.origin + out_dir * host_r * rng.randf_range(0.95, 1.15) + out_dir * r * 0.6
		var from_core := (at - core).normalized()
		transforms.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(r * rng.randf_range(1.0, 1.5), r * 0.62, r)), at))
		customs.append(Color(rng.randf(), -2.0, clampf((at.y - base_y) / maxf(height, 1.0), 0.0, 1.0), 1.0))
		colors.append(Color(from_core.x * 0.5 + 0.5, from_core.y * 0.5 + 0.5, from_core.z * 0.5 + 0.5, 1.0))


## Daughter Of The Wind's noise: red a smooth fBm, green cell noise (round domes with creases), tiling.
func _make_noise() -> ImageTexture:
	var noise := FastNoiseLite.new()
	noise.seed = seed
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.012
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = 4
	var smooth: Image = noise.get_seamless_image(256, 256, false, false, 0.1, true)
	var cells := FastNoiseLite.new()
	cells.seed = seed + 3
	cells.noise_type = FastNoiseLite.TYPE_CELLULAR
	cells.frequency = 0.03
	cells.fractal_type = FastNoiseLite.FRACTAL_NONE
	cells.cellular_distance_function = FastNoiseLite.DISTANCE_EUCLIDEAN
	cells.cellular_return_type = FastNoiseLite.RETURN_DISTANCE
	var bumps: Image = cells.get_seamless_image(256, 256, false, false, 0.1, true)
	var image := Image.create(256, 256, false, Image.FORMAT_RG8)
	for y in 256:
		for x in 256:
			image.set_pixel(x, y, Color(smooth.get_pixel(x, y).r, bumps.get_pixel(x, y).r, 0.0))
	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)
