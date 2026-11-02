class_name BirdCamera
extends Camera3D
## The camera that follows the bird he plays as (BirdPlayer): round it as the look stick, a right-drag of the mouse or
## a drag on a phone turns it; flying, left alone, it swings round behind the way the bird goes. Kept off walls.

var bird: BirdPlayer
var distance := 3.0
var _yaw := 0.0
var _pitch := 0.35
var _since_look := 10.0


func _ready() -> void:
	fov = 62.0
	far = 3000.0


## Turned to look the way `along` goes, from behind.
func look_along(along: Vector3) -> void:
	_yaw = atan2(-along.x, -along.z)
	_since_look = 10.0
	_place()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_RIGHT:
		_turn(event.relative * 0.005)


func _turn(by: Vector2) -> void:
	_yaw -= by.x
	_pitch = clampf(_pitch + by.y, -0.5, 1.2)
	_since_look = 0.0


func _process(delta: float) -> void:
	if not is_instance_valid(bird):
		return
	var stick := Input.get_vector(&"look_left", &"look_right", &"look_up", &"look_down")
	var touch: TouchControls = bird.world.player._touch if bird.world and bird.world.player else null
	if touch:
		var drag := touch.take_look()
		if drag.length_squared() > 0.0:
			_turn(drag * 0.005)
	if stick.length_squared() > 0.0 and not Player.input_blocked:
		_turn(stick * stick.length() * Vector2(2.6, 1.6) * delta)
	_since_look += delta
	# (flying and left alone: round behind it, looking a little down on it)
	var flat := Vector3(bird.velocity.x, 0.0, bird.velocity.z)
	if bird.flying and _since_look > 1.2 and flat.length() > 1.0:
		_yaw = lerp_angle(_yaw, atan2(-flat.x, -flat.z), 1.0 - exp(-2.2 * delta))
		_pitch = lerpf(_pitch, 0.3, 1.0 - exp(-1.5 * delta))
	_place()


func _place() -> void:
	if not is_instance_valid(bird) or not is_inside_tree():
		return
	var away := Vector3(sin(_yaw) * cos(_pitch), sin(_pitch), cos(_yaw) * cos(_pitch))
	var pivot := bird.global_position + Vector3.UP * 0.35
	var reach := distance
	var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(pivot, pivot + away * (reach + 0.2), 1))
	if not hit.is_empty():
		reach = maxf(pivot.distance_to(hit.position) - 0.2, 0.4)
	global_transform = Transform3D(Basis.looking_at(-away, Vector3.UP), pivot + away * reach)
