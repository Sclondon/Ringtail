class_name Waterfall
extends Node3D
## A waterfall, stylised but rich (Wind Waker-ish, for a cel-shaded game): a curved sheet of water spilling over a
## lip and falling in an arc from `top` to `bottom`, streaky and scrolling, a white curl of water at the lip, breaking
## into white water as it falls; at its foot spray thrown up, a drift of mist, a churning patch of foam on the pool
## (FoamPatch) and rings spreading from it on that pool's `Water`. One sheet, one foam patch, two particle draws.
## No textures. Made for Ringtail's grove spring (2026-11-02).
##
##   var falls := Waterfall.new()
##   falls.top = lip_middle            # world space, at the water's level where it goes over
##   falls.bottom = where_it_lands     # world space, on the surface below
##   falls.pool = pond_water           # optional: a Water to ring and splash
##   add_child(falls)

## Where it goes over (the middle of the lip) and where it lands, in world space.
@export var top := Vector3.ZERO
@export var bottom := Vector3(0.0, -2.0, 0.6)
## How wide the sheet is at the lip, and how much wider it spreads by the foot.
@export var width := 0.7
@export var spread := 1.35
## How far the water runs flat over the lip before it falls (metres back from `top`), drawn as the white curl.
@export var lip := 0.35
## How fast the water falls (metres a second, down the sheet), and its colours.
@export var speed := 2.2
@export var water_colour := Color(0.45, 0.72, 0.85)
@export var foam_colour := Color(0.95, 0.99, 1.0)
## The Water it falls into, if any: rings spread on it from where the falls land and it churns.
@export var pool: Water
## How much spray and mist (0 none, 1 the full amount).
@export_range(0.0, 2.0) var spray := 1.0

const SHADER := """
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, shadows_disabled, diffuse_toon, specular_disabled;
uniform vec3 water_colour : source_color = vec3(0.45, 0.72, 0.85);
uniform vec3 foam_colour : source_color = vec3(0.95, 0.99, 1.0);
uniform float speed = 2.2;
uniform float length_m = 3.0;
uniform float lip_m = 0.35;

float hash(vec2 p) {
	uvec2 q = uvec2(ivec2(floor(p)) + 32768) * uvec2(1597334673u, 3812015801u);
	uint n = (q.x ^ q.y) * 1597334673u;
	return float(n) * (1.0 / 4294967295.0);
}
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0)), f.x), f.y);
}

void fragment() {
	// UV.x across the sheet (0..1), UV.y metres down it from the back of the lip
	float across = UV.x;
	float down = UV.y;
	float flow = down - TIME * speed;
	// (streaks: columns of noise stretched down the sheet, scrolling with the water; finer ones over coarse)
	float streaks = noise(vec2(across * 9.0, flow * 0.9)) * 0.6 + noise(vec2(across * 23.0 + 7.0, flow * 2.2)) * 0.4;
	float after = clamp((down - lip_m) / max(length_m - lip_m, 0.01), 0.0, 1.0);
	// (white: the curl at the lip, white water breaking out more and more as it falls, heaviest near the foot)
	float curl = smoothstep(lip_m * 0.4, lip_m, down) * smoothstep(lip_m + 0.35, lip_m, down);
	float breaking = smoothstep(0.75 - 0.5 * after, 0.95 - 0.45 * after, streaks);
	float white = clamp(curl * 0.9 + breaking + smoothstep(0.75, 1.0, after) * 0.5, 0.0, 1.0);
	// (ragged, see-through edges that waver; the sheet thins and breaks apart in strands near its sides)
	float edge = min(across, 1.0 - across) * 2.0;
	float ragged = edge - (noise(vec2(flow * 1.6, across * 3.0 + 11.0)) - 0.5) * 0.5 * (0.4 + after);
	float body = smoothstep(0.0, 0.28, ragged);
	float strands = mix(1.0, smoothstep(0.3, 0.6, streaks), (1.0 - smoothstep(0.1, 0.5, edge)) * after);
	float alpha = body * strands * mix(0.72, 0.95, white);
	if (alpha < 0.04) {
		discard;
	}
	vec3 water = mix(water_colour * (0.8 + 0.35 * streaks), water_colour * 1.25, curl);
	ALBEDO = mix(water, foam_colour, white);
	ALPHA = alpha;
	EMISSION = ALBEDO * 0.12;
}
"""

static var _shader: Shader

var _sheet: MeshInstance3D
var _churn: FoamPatch
var _spray: CPUParticles3D
var _mist: CPUParticles3D
var _ring_in := 0.0
var _splash_in := 1.0


func _ready() -> void:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER
	_build()


## Builds it again (after `top`, `bottom`, `width` or the colours change).
func rebuild() -> void:
	for child in get_children():
		child.queue_free()
	_build()


func _build() -> void:
	var length := _sheet_mesh()
	var material := ShaderMaterial.new()
	material.shader = _shader
	material.set_shader_parameter(&"water_colour", water_colour)
	material.set_shader_parameter(&"foam_colour", foam_colour)
	material.set_shader_parameter(&"speed", speed)
	material.set_shader_parameter(&"length_m", length)
	material.set_shader_parameter(&"lip_m", lip)
	_sheet.material_override = material
	# The churn where it lands, spray thrown up out of it, mist drifting off
	var foot := bottom - global_position
	_churn = FoamPatch.new()
	_churn.radius = width * spread * 0.95
	_churn.colour = foam_colour
	_churn.speed = 0.8
	_churn.position = foot + Vector3.UP * 0.012
	add_child(_churn)
	_spray = _particles(foot, 26, 0.7, Color(foam_colour, 0.85), 0.04, 0.09)
	_spray.direction = Vector3.UP
	_spray.spread = 40.0
	_spray.initial_velocity_min = 1.2
	_spray.initial_velocity_max = 2.6
	_spray.gravity = Vector3(0.0, -7.0, 0.0)
	_spray.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_spray.emission_sphere_radius = width * 0.4
	_mist = _particles(foot + Vector3.UP * 0.25, 8, 2.2, Color(foam_colour, 0.16), 0.35, 0.7)
	_mist.direction = Vector3.UP
	_mist.spread = 70.0
	_mist.initial_velocity_min = 0.15
	_mist.initial_velocity_max = 0.45
	_mist.gravity = Vector3(0.0, 0.05, 0.0)
	_mist.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_mist.emission_sphere_radius = width * 0.6
	var fade := Curve.new()
	fade.add_point(Vector2(0.0, 0.3))
	fade.add_point(Vector2(0.3, 1.0))
	fade.add_point(Vector2(1.0, 0.0))
	_spray.scale_amount_curve = fade
	_mist.scale_amount_curve = fade


## The sheet: a ribbon from behind the lip, over it, and down in the arc water falls in (it leaves the lip level and
## drops as a thrown thing does), curved across (bowed out in the middle), widening as it goes. Returns its length.
func _sheet_mesh() -> float:
	_sheet = MeshInstance3D.new()
	_sheet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_sheet)
	var way := Vector3(bottom.x - top.x, 0.0, bottom.z - top.z)
	var reach := way.length()
	way = way.normalized() if reach > 0.01 else Vector3.FORWARD
	var side := way.cross(Vector3.UP).normalized()
	var drop := maxf(top.y - bottom.y, 0.1)
	var origin := global_position
	var rows := 26
	var cols := 7
	var points: Array[Vector3] = []
	# (the path: flat over the lip, then a parabola from the lip to the foot)
	for i in rows + 1:
		var s := float(i) / rows
		var p: Vector3
		var lip_share := 0.18
		if s < lip_share:
			p = top - way * lip * (1.0 - s / lip_share)
		else:
			var t := (s - lip_share) / (1.0 - lip_share)
			p = top + way * reach * t + Vector3.DOWN * drop * t * t
		points.append(p)
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var length := 0.0
	var along := [0.0]
	for i in range(1, points.size()):
		length += points[i].distance_to(points[i - 1])
		along.append(length)
	for i in points.size():
		var s := float(i) / rows
		var tangent := (points[mini(i + 1, rows)] - points[maxi(i - 1, 0)]).normalized()
		var facing := tangent.cross(side).normalized()
		var half := width * 0.5 * lerpf(1.0, spread, smoothstep(0.15, 1.0, s))
		for j in cols + 1:
			var u := float(j) / cols
			var x := (u - 0.5) * 2.0
			# (bowed out in the middle and in at the sides: a curved sheet, not a flat card)
			var bow := (1.0 - x * x) * 0.08 * smoothstep(0.1, 0.4, s)
			verts.append(points[i] + side * x * half + facing * bow - origin)
			normals.append(facing)
			uvs.append(Vector2(u, along[i]))
	var indices := PackedInt32Array()
	for i in rows:
		for j in cols:
			var a := i * (cols + 1) + j
			var b := a + cols + 1
			indices.append_array([a, b, a + 1, a + 1, b, b + 1])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_sheet.mesh = mesh
	return length


func _particles(at: Vector3, amount: int, life: float, colour: Color, small: float, big: float) -> CPUParticles3D:
	var bits := CPUParticles3D.new()
	bits.position = at
	bits.amount = maxi(1, roundi(amount * spray))
	bits.lifetime = life
	bits.scale_amount_min = small
	bits.scale_amount_max = big
	bits.emitting = spray > 0.0
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	var paint := StandardMaterial3D.new()
	paint.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	paint.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	paint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	paint.vertex_color_use_as_albedo = true
	paint.albedo_color = colour
	var dot := GradientTexture2D.new()
	dot.fill = GradientTexture2D.FILL_RADIAL
	dot.fill_from = Vector2(0.5, 0.5)
	dot.fill_to = Vector2(1.0, 0.5)
	var soft := Gradient.new()
	soft.set_color(0, Color(1, 1, 1, 1))
	soft.set_color(1, Color(1, 1, 1, 0))
	dot.gradient = soft
	dot.width = 32
	dot.height = 32
	paint.albedo_texture = dot
	quad.material = paint
	bits.mesh = quad
	add_child(bits)
	return bits


func _process(delta: float) -> void:
	if pool == null or not is_instance_valid(pool):
		return
	# (rings spreading on the pool from where it lands, and now and then a splash of drops out of the churn)
	_ring_in -= delta
	if _ring_in <= 0.0:
		_ring_in = randf_range(0.18, 0.32)
		var off := Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0)) * width * 0.5
		pool.ripple(bottom + off, randf_range(0.35, 0.6))
	_splash_in -= delta
	if _splash_in <= 0.0:
		_splash_in = randf_range(0.9, 1.8)
		pool.splash(bottom, 0.2 * spray)
