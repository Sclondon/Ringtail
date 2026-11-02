class_name Race
extends Area3D
## The stopwatch: run into it and a trail of glowing race crumbs lights up along the
## alley; take them all before the time runs out and the race's Bottlecap appears.
## Miss and they go out, and the stopwatch can be started again.

signal started
signal won
signal lost

@export var time_limit := 25.0

var route: Array[Vector3] = []
var left := 0.0
var running := false
var _crumbs: Array[Pickup] = []
var _watch: Node3D
var _t := 0.0
var _rest := 0.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	var shape := SphereShape3D.new()
	shape.radius = 0.6
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.position.y = 0.6
	add_child(collider)
	_watch = (load("res://models/stopwatch.glb") as PackedScene).instantiate()
	_watch.position.y = 0.7
	_watch.scale = Vector3.ONE * 1.6
	add_child(_watch)
	Toon.apply(_watch)
	body_entered.connect(_on_body)


func _process(delta: float) -> void:
	_t += delta
	_rest = maxf(_rest - delta, 0.0)
	_watch.rotation.y = _t * (6.0 if running else 1.2)
	_watch.visible = not running
	if not running:
		return
	left -= delta
	if left <= 0.0:
		running = false
		for crumb in _crumbs:
			if is_instance_valid(crumb):
				crumb.queue_free()
		_crumbs.clear()
		_rest = 1.5
		lost.emit()


func _on_body(body: Node) -> void:
	if body is Player and not running and _rest <= 0.0 and not route.is_empty():
		# (not inside the physics signal: the pickups it makes set up their areas)
		start.call_deferred()


func start() -> void:
	running = true
	left = time_limit
	_crumbs.clear()
	for at in route:
		var crumb := Pickup.make(Pickup.Kind.RACE, at)
		crumb.taken.connect(_on_taken)
		get_parent().add_child(crumb)
		_crumbs.append(crumb)
	started.emit()


func _on_taken(crumb: Pickup) -> void:
	_crumbs.erase(crumb)
	if running and _crumbs.is_empty():
		running = false
		won.emit()


## How many race crumbs are still to take.
func remaining() -> int:
	return _crumbs.size()
