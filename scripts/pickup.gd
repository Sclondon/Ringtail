class_name Pickup
extends Area3D
## Something to take by running into it: a Crumb (some bit of food: an apple, an acorn, a slice of pizza,
## rubbish... tools/build_food.py) or a Bottlecap (placeholder names), or a race crumb. It turns and
## bobs, with a faint rim of light and now and then a sparkle; taken, it bursts (the user, 2026-11-02: "food items
## should have a faint rim light and sparkle", "instead of just rising up when collected they should burst").
## (After Gloaming's Pickup.)

signal taken(pickup: Pickup)

enum Kind { CRUMB, CAP, RACE }

const MODELS := {
	Kind.CRUMB: preload("res://models/crumb.glb"),
	Kind.CAP: preload("res://models/cap.glb"),
	Kind.RACE: preload("res://models/crumb.glb"),
}
## The foods a Crumb may be (the user, 2026-11-01: "the items to pick up should be different food items - apples,
## acorns, pizza slices, garbage, etc"): [model, how many in the mix, how far it is tipped to show its top, how big it is drawn].
const FOODS := [
	[preload("res://models/food_apple.glb"), 4, 0.0, 1.0],
	[preload("res://models/food_acorn.glb"), 4, 0.0, 1.0],
	[preload("res://models/food_pizza.glb"), 2, 0.6, 1.0],
	[preload("res://models/food_core.glb"), 2, 0.0, 1.0],
	[preload("res://models/food_cheese.glb"), 2, 0.25, 1.0],
	[preload("res://models/food_banana.glb"), 1, 0.35, 1.0],
	[preload("res://models/food_fishbone.glb"), 1, 0.0, 1.3],
	[preload("res://models/food_donut.glb"), 1, 0.5, 1.35],
]

var kind := Kind.CRUMB
## The cap's name (its marker's: roof, glide, cats, race, hidden).
var tag := ""
var _spin: Node3D
var _t := randf() * TAU
var _gone := -1.0
## Its sparkles: when each next twinkles, and where.
var _glints: Array[MeshInstance3D] = []
var _glint_at: Array[float] = []

## The rim of light over the food, the twinkling star, shared by every pickup.
static var _rim_material: ShaderMaterial
static var _star_material: ShaderMaterial
static var _star_mesh: QuadMesh

const RIM_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back;
uniform vec3 rim_colour = vec3(1.0, 0.95, 0.78);
uniform float strength = 0.75;
void fragment() {
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.5);
	ALBEDO = rim_colour * rim * strength;
}
"""

## A four-pointed star facing the camera (its size the node's scale), added over what is behind it.
const STAR_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
uniform vec3 colour = vec3(1.0, 0.96, 0.8);
void vertex() {
	float s = length(MODEL_MATRIX[0].xyz);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * s, INV_VIEW_MATRIX[1] * s, INV_VIEW_MATRIX[2] * s, MODEL_MATRIX[3]);
}
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float arms = max(1.0 - abs(p.x) * 9.0 - abs(p.y), 0.0) + max(1.0 - abs(p.y) * 9.0 - abs(p.x), 0.0);
	float core = max(1.0 - length(p) * 3.0, 0.0);
	ALBEDO = colour * (arms + core) * COLOR.a;
}
"""


static func make(what: Kind, at: Vector3, called := "") -> Pickup:
	var pickup := Pickup.new()
	pickup.kind = what
	pickup.tag = called
	pickup.position = at
	return pickup


func _ready() -> void:
	add_to_group(&"pickups")
	# (he looks at it as he passes)
	add_to_group(&"interest")
	collision_layer = 0
	collision_mask = 2
	monitorable = false
	var shape := SphereShape3D.new()
	shape.radius = 0.55 if kind == Kind.CAP else 0.42
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.position.y = 0.3
	add_child(collider)
	_spin = Node3D.new()
	_spin.position.y = 0.45 if kind == Kind.CAP else 0.25
	add_child(_spin)
	var model: Node3D
	if kind == Kind.CRUMB:
		var food: Array = _food()
		model = (food[0] as PackedScene).instantiate()
		model.rotation.x = food[2]
		model.scale = Vector3.ONE * float(food[3])
		model.position.y = -0.12
	else:
		model = MODELS[kind].instantiate()
	_spin.add_child(model)
	Toon.apply(model)
	# (a faint rim of light round it, and two glints that twinkle now and then)
	_shine(model)
	if kind == Kind.CAP:
		model.scale = Vector3.ONE * 1.6
		var light := OmniLight3D.new()
		light.light_color = Color(1.0, 0.85, 0.4)
		light.omni_range = 3.0
		light.light_energy = 1.2
		_spin.add_child(light)
	elif kind == Kind.RACE:
		model.scale = Vector3.ONE * 1.5
		var light := OmniLight3D.new()
		light.light_color = Color(0.5, 0.9, 1.0)
		light.omni_range = 2.0
		_spin.add_child(light)
	body_entered.connect(_on_body)


## Which food this Crumb is: the same spot always gives the same one, apples and acorns the likeliest.
func _food() -> Array:
	var spot := Vector3i((position * 10.0).round())
	var total := 0
	for food: Array in FOODS:
		total += int(food[1])
	var pick := absi(hash(spot)) % total
	for food: Array in FOODS:
		pick -= int(food[1])
		if pick < 0:
			return food
	return FOODS[0]


func _process(delta: float) -> void:
	_t += delta
	if _gone >= 0.0:
		# (it swells for an instant and is gone, bursting into sparks)
		_gone += delta
		_spin.scale = Vector3.ONE * (1.0 + _gone * 6.0 if _gone < 0.06 else 0.0)
		if _gone > 0.7:
			queue_free()
		return
	for k in _glints.size():
		var since := _t - _glint_at[k]
		if since > 0.45:
			# (the next twinkle, somewhere else on it, in a while)
			_glint_at[k] = _t + randf_range(0.2, 1.2)
			var a := randf() * TAU
			_glints[k].position = Vector3(cos(a) * 0.14, randf_range(-0.06, 0.14), sin(a) * 0.14)
			since = _t - _glint_at[k]
		var bright := sin(PI * clampf(since / 0.45, 0.0, 1.0)) if since >= 0.0 else 0.0
		_glints[k].scale = Vector3.ONE * maxf(0.16 * bright, 0.001)
		_glints[k].rotation.z = since * 3.0
	_spin.rotation.y = _t * (1.6 if kind == Kind.CAP else 2.4)
	_spin.position.y = (0.45 if kind == Kind.CAP else 0.25) + sin(_t * 3.0) * 0.05


func _on_body(body: Node) -> void:
	# (a Crumb is taken by a bird he plays as too: BirdPlayer)
	if not (body is Player or (body is BirdPlayer and kind == Kind.CRUMB)) or _gone >= 0.0:
		return
	take()


## Takes it (as the player running into it does).
func take() -> void:
	if _gone >= 0.0:
		return
	_gone = 0.0
	set_deferred(&"monitoring", false)
	_burst()
	taken.emit(self)


## The rim of light on every part of `model`, and its glints.
func _shine(model: Node3D) -> void:
	if _rim_material == null:
		var rim := Shader.new()
		rim.code = RIM_SHADER
		_rim_material = ShaderMaterial.new()
		_rim_material.shader = rim
		var star := Shader.new()
		star.code = STAR_SHADER
		_star_material = ShaderMaterial.new()
		_star_material.shader = star
		_star_mesh = QuadMesh.new()
		_star_mesh.size = Vector2.ONE
		_star_mesh.material = _star_material
	# (a pass after each of its own materials, which Toon made for it alone)
	for part: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		for surface in part.mesh.get_surface_count():
			var own := part.get_surface_override_material(surface)
			if own:
				own.next_pass = _rim_material
	for k in 2:
		var glint := MeshInstance3D.new()
		glint.mesh = _star_mesh
		glint.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		glint.scale = Vector3.ONE * 0.001
		_spin.add_child(glint)
		_glints.append(glint)
		_glint_at.append(_t + randf_range(0.0, 2.0))


## Taken: a burst of sparks flying out from where it was.
func _burst() -> void:
	var sparks := CPUParticles3D.new()
	sparks.mesh = _star_mesh
	sparks.one_shot = true
	sparks.explosiveness = 1.0
	sparks.amount = 16 if kind != Kind.CAP else 28
	sparks.lifetime = 0.55
	sparks.direction = Vector3.UP
	sparks.spread = 180.0
	sparks.initial_velocity_min = 1.6
	sparks.initial_velocity_max = 3.2
	sparks.gravity = Vector3(0.0, -3.0, 0.0)
	sparks.damping_min = 2.0
	sparks.damping_max = 4.0
	sparks.scale_amount_min = 0.1
	sparks.scale_amount_max = 0.2
	var fade := Curve.new()
	fade.add_point(Vector2(0.0, 1.0))
	fade.add_point(Vector2(1.0, 0.0))
	sparks.scale_amount_curve = fade
	sparks.position = _spin.position
	add_child(sparks)
	sparks.emitting = true
	for glint in _glints:
		glint.visible = false
