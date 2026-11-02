class_name GroveSnake
extends Node3D
## A garter snake (the user, 2026-11-02: "and snakes"): tools/build_snake.py's straight snake, bent in its vertex
## shader. Slithering, its body follows a travelling S-wave that stays put on the ground as it goes, so every part of
## it passes along the same track (the phase moves with the distance it has gone); coiled, it lies in a flat spiral
## with its head on top in the middle; its tongue flicks out and back. GroveAnimals moves it about and says which.
## Its middle is at this node; it faces +Z.

const LENGTH := 0.9
## The S-wave: how long one wave is (m) and how far it swings out at most (m).
const WAVE := 0.34
const SWING := 0.055

const _BEND := """
uniform float body_length = 0.9;
uniform float phase = 0.0;
uniform float swing = 0.05;
uniform float wave = 18.48;
uniform float coil = 0.0;
uniform float flick = 0.0;
uniform float lift = 0.0;

// The line down its middle, `d` metres back from the front of its head: laid out straight and waving, or coiled.
vec3 straight(float d) {
	float out_ = swing * smoothstep(0.0, 0.2, d) * (0.7 + 0.3 * smoothstep(0.2, 0.6, d));
	float head_up = lift * (1.0 - smoothstep(0.0, 0.16, d));
	return vec3(out_ * sin(wave * d - phase), 0.02 + head_up, body_length * 0.5 - d);
}

vec3 coiled(float d) {
	// (an Archimedean spiral out from its head, one body's width a turn: its head in the middle, on top)
	float r0 = 0.045;
	float c = 0.0075;
	float turn = (-r0 + sqrt(r0 * r0 + 2.0 * c * d)) / c;
	float r = r0 + c * turn;
	float head_up = 0.035 * (1.0 - smoothstep(0.0, 0.12, d)) + lift * (1.0 - smoothstep(0.0, 0.16, d));
	return vec3(r * sin(-turn), 0.02 + head_up, r * cos(-turn) - r0 + 0.02);
}

vec3 middle(float d) {
	return mix(straight(d), coiled(d), coil);
}

void vertex() {
	float z = VERTEX.z;
	float d = body_length - min(z, body_length);
	// (past the front of its head: the tongue, out as far as `flick`)
	float past = max(z - body_length, 0.0) * flick;
	vec3 at = middle(d);
	vec3 ahead = normalize(middle(max(d - 0.004, 0.0)) - middle(d + 0.004));
	vec3 side = normalize(cross(vec3(0.0, 1.0, 0.0), ahead));
	vec3 up = cross(ahead, side);
	VERTEX = at + side * VERTEX.x + up * VERTEX.y + ahead * past;
	NORMAL = normalize(side * NORMAL.x + up * NORMAL.y + ahead * NORMAL.z);
}

"""

static var _shader: Shader

## Slithering speed (m/s, along its body); 0 still.
var speed := 0.0
## 0 laid out, 1 coiled.
var coil := 0.0
## Its head raised (m).
var lift := 0.0
var _coiled := 0.0
var _gone := 0.0
var _flick := 0.0
var _flick_wait := 1.0
var _materials: Array[ShaderMaterial] = []
var _model: Node3D


func _ready() -> void:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = Toon.SHADER.replace("void fragment() {", _BEND + "void fragment() {")
	_model = (load("res://models/snake.glb") as PackedScene).instantiate()
	add_child(_model)
	for part: MeshInstance3D in _model.find_children("*", "MeshInstance3D", true, false):
		# (bent in the shader: keep it from being culled where it was built)
		part.extra_cull_margin = 0.6
		for surface in part.mesh.get_surface_count():
			var original := part.mesh.surface_get_material(surface) as StandardMaterial3D
			var made := ShaderMaterial.new()
			made.shader = _shader
			made.set_shader_parameter(&"albedo", original.albedo_color if original else Color.DARK_OLIVE_GREEN)
			made.set_shader_parameter(&"body_length", LENGTH)
			made.set_shader_parameter(&"wave", TAU / WAVE)
			if original and original.resource_name == "eye":
				made.set_shader_parameter(&"highlight", 0.5)
				made.set_shader_parameter(&"gloss", 90.0)
			part.set_surface_override_material(surface, made)
			_materials.append(made)


func _process(delta: float) -> void:
	_gone += speed * delta
	_coiled = move_toward(_coiled, coil, delta * 0.7)
	# The tongue: out and back in a quick double flick now and then, more often when it is about
	_flick_wait -= delta
	if _flick_wait <= 0.0:
		_flick += delta * 6.0
		if _flick >= 2.0:
			_flick = 0.0
			_flick_wait = randf_range(0.8, 2.6) if speed > 0.0 else randf_range(1.5, 5.0)
	var tongue := sin(clampf(_flick, 0.0, 2.0) * PI) ** 2 if _flick > 0.0 else 0.0
	var swinging := SWING * clampf(speed / 0.25, 0.25, 1.0) * (1.0 - _coiled)
	for made in _materials:
		made.set_shader_parameter(&"phase", _gone * TAU / WAVE)
		made.set_shader_parameter(&"swing", swinging)
		made.set_shader_parameter(&"coil", smoothstep(0.0, 1.0, _coiled))
		made.set_shader_parameter(&"flick", tongue)
		made.set_shader_parameter(&"lift", lift)
