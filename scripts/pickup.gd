class_name Pickup
extends Area3D
## Something to take by running into it: a Crumb (some bit of food: an apple, an acorn, a slice of pizza,
## rubbish... tools/build_food.py) or a Bottlecap (placeholder names), or a race crumb. It turns and
## bobs; taken, it hops up, shrinks and is gone.
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
		_gone += delta
		_spin.position.y += delta * 3.0
		_spin.scale = Vector3.ONE * maxf(0.0, 1.0 - _gone * 3.0)
		_spin.rotation.y += delta * 20.0
		if _gone > 0.34:
			queue_free()
		return
	_spin.rotation.y = _t * (1.6 if kind == Kind.CAP else 2.4)
	_spin.position.y = (0.45 if kind == Kind.CAP else 0.25) + sin(_t * 3.0) * 0.05


func _on_body(body: Node) -> void:
	if not body is Player or _gone >= 0.0:
		return
	take()


## Takes it (as the player running into it does).
func take() -> void:
	if _gone >= 0.0:
		return
	_gone = 0.0
	set_deferred(&"monitoring", false)
	taken.emit(self)
