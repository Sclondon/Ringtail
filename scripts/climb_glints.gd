class_name ClimbGlints
extends Node3D
## While scurry is held, little blue sparkles twinkle on whatever climbable is near (the user, 2026-11-02: "When you
## hold scurry nearby climbable objects should have little blue sparkles"), and from further off ("the blue
## sparkles should appear from further"): a fan of rays round him at a few heights
## finds the climbable faces within `reach`, and a glint comes up here and there on them, twinkles and goes. A child
## of Scurry (it makes one).

## How far round him climbables sparkle, how many glints there are at most, and how often new ones come up.
@export var reach := 14.0
const GLINTS := 64
const EVERY := 0.035
const LIFE := 0.5

var scurry: Scurry
var _glints: Array[MeshInstance3D] = []
var _born: Array[float] = []
var _size: Array[float] = []
var _next := 0
var _clock := 0.0
var _wait := 0.0
var _hits: Array[Vector3] = []
var _look_in := 0.0


func _ready() -> void:
	top_level = true
	var shader := Shader.new()
	# (the pickups' star, but painted on, not added to the light behind it: a dark blue can show then; the user,
	# 2026-11-02, "the climbing sparkles need to appear from farther away and be a darker blue")
	shader.code = Pickup.STAR_SHADER.replace("blend_add", "blend_mix").replace(
			"ALBEDO = colour * (arms + core) * COLOR.a;",
			# (with a little bright spot at its heart: the user, "the blue sparkles should have a little bright spot in
			# them too")
			"ALBEDO = mix(colour, vec3(1.0), clamp(core * 2.6, 0.0, 1.0));\n\tALPHA = clamp((arms + core) * COLOR.a * 1.6, 0.0, 1.0);")
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter(&"colour", Vector3(0.08, 0.22, 0.85))
	var star := QuadMesh.new()
	star.size = Vector2.ONE
	star.material = material
	for k in GLINTS:
		var glint := MeshInstance3D.new()
		glint.mesh = star
		glint.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		glint.visible = false
		add_child(glint)
		_glints.append(glint)
		_born.append(-10.0)
		_size.append(0.14)


func _process(delta: float) -> void:
	_clock += delta
	var player := scurry.get_parent() as Player
	var on := scurry.held and not scurry.climbing
	if on:
		_look_in -= delta
		if _look_in <= 0.0:
			_look_in = 0.2
			_find(player)
		_wait -= delta
		while _wait <= 0.0 and not _hits.is_empty():
			_wait += EVERY
			var at: Vector3 = _hits[randi() % _hits.size()]
			var k := _next
			_next = (_next + 1) % GLINTS
			_glints[k].global_position = at + Vector3(randf_range(-0.12, 0.12), randf_range(-0.25, 0.25), randf_range(-0.12, 0.12))
			_born[k] = _clock
			# (bigger further off, so a far one still shows)
			_size[k] = 0.14 * maxf(1.0, at.distance_to(player.global_position) / 3.0)
			_glints[k].visible = true
	else:
		_hits.clear()
	for k in GLINTS:
		if not _glints[k].visible:
			continue
		var age := (_clock - _born[k]) / LIFE
		if age >= 1.0:
			_glints[k].visible = false
			continue
		_glints[k].scale = Vector3.ONE * maxf(_size[k] * sin(PI * age), 0.001)


## The climbable faces round him now: where a fan of rays from him meets them.
func _find(player: Player) -> void:
	_hits.clear()
	var space := player.get_world_3d().direct_space_state
	for high: float in [0.3, 1.0, 1.8]:
		var from := player.global_position + Vector3.UP * high
		for k in 48:
			var a := TAU * k / 48.0
			var query := PhysicsRayQueryParameters3D.create(from, from + Vector3(cos(a), 0.0, sin(a)) * reach, 1)
			query.exclude = [player.get_rid()]
			var hit := space.intersect_ray(query)
			if hit.is_empty():
				continue
			var body: Node = hit.collider
			if body.is_in_group(&"climbable") or (body.get_parent() and body.get_parent().is_in_group(&"climbable")):
				_hits.append((hit.position as Vector3) + (hit.normal as Vector3) * 0.04)
