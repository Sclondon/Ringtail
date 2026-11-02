class_name FoamPatch
extends MeshInstance3D
## A round patch of churning white water lying on a surface: where a waterfall comes down, or a spring wells up.
## Ragged foam that boils outward from its middle and breaks up towards its edge, flecks drifting out over it, the
## whole of it breathing. One quad, one material, no textures. Lay it just over the water (Waterfall and WaterSpring
## make their own).
##
##   var churn := FoamPatch.new()
##   churn.radius = 0.9
##   churn.position = Vector3(0.0, 0.01, 0.0)   # on the surface
##   add_child(churn)

## How far it reaches (metres), how much of it is white at its heart, how fast it boils outward.
@export var radius := 0.8: set = _set_radius
@export_range(0.0, 1.0) var strength := 0.85: set = _set_strength
@export var speed := 0.5: set = _set_speed
@export var colour := Color(0.95, 0.99, 1.0): set = _set_colour

const SHADER := """
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, shadows_disabled, diffuse_toon, specular_disabled;
uniform vec3 colour : source_color = vec3(0.95, 0.99, 1.0);
uniform float strength = 0.85;
uniform float speed = 0.5;
uniform float seed = 0.0;

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
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	if (r > 1.0) {
		discard;
	}
	float a = atan(p.y, p.x);
	// (the foam boils outward: noise in rings that move out from the middle, broken round the circle)
	float outward = r * 3.0 - TIME * speed * 2.0;
	float lumps = noise(vec2(a * 3.0 + seed, outward * 2.0)) * 0.6 + noise(vec2(a * 7.0 - seed, outward * 5.0 + 3.0)) * 0.4;
	float flecks = step(0.8, noise(vec2(a * 14.0 + seed * 2.0, outward * 9.0)));
	float body = smoothstep(1.0, 0.15, r) * (0.55 + 0.45 * sin(TIME * 2.3 + seed));
	float white = smoothstep(0.45 - 0.35 * body, 0.6 - 0.3 * body, lumps) + flecks * (1.0 - r) * 0.8;
	white *= strength * smoothstep(1.0, 0.7, r);
	if (white < 0.08) {
		discard;
	}
	ALBEDO = colour;
	ALPHA = clamp(white, 0.0, 0.95);
	EMISSION = colour * 0.08;
}
"""

static var _shader: Shader


func _ready() -> void:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER
	var quad := QuadMesh.new()
	quad.orientation = PlaneMesh.FACE_Y
	mesh = quad
	var material := ShaderMaterial.new()
	material.shader = _shader
	material.set_shader_parameter(&"seed", randf() * 50.0)
	material_override = material
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_apply()


func _apply() -> void:
	if mesh == null:
		return
	(mesh as QuadMesh).size = Vector2.ONE * radius * 2.0
	var material := material_override as ShaderMaterial
	material.set_shader_parameter(&"strength", strength)
	material.set_shader_parameter(&"speed", speed)
	material.set_shader_parameter(&"colour", colour)


func _set_radius(value: float) -> void:
	radius = value
	_apply()


func _set_strength(value: float) -> void:
	strength = value
	_apply()


func _set_speed(value: float) -> void:
	speed = value
	_apply()


func _set_colour(value: Color) -> void:
	colour = value
	_apply()
