class_name Pee
extends Node
## Holding the pee button (the user, 2026-11-02: "holding down on the dpad should be a piss button", "he should pee
## like a dude at a urinal and you should be able to aim it", "it shouldn't have an onscreen button"): D-pad down, or V.
## Stood on the ground he stands up straight at it (RaccoonRig.peeing) and a yellow trickle arcs out ahead of him; the
## stick aims it (left and right, near and far) instead of walking him, and a puddle spreads where it lands and soaks
## away after a while. No on-screen button, by the user's word. The stream and the puddle are Claude's picks.

## How big a puddle grows (metres across) and how long it takes to soak away.
const PUDDLE_MOST := 0.5
const SOAK := 25.0
## How far the aim turns it (radians either side) and how hard it is sent (near to far).
const AIM_TURN := 0.8
const SPEED_NEAR := 0.7
const SPEED_FAR := 1.9

var _player: Player
var _rig: RaccoonRig
var _stream: CPUParticles3D
## A tiny splash where it lands (the user, 2026-11-02: "it needs a tiny splashy particle").
var _splash: CPUParticles3D
var _puddle: MeshInstance3D
## Every puddle still lying about, oldest first (at most MOST_PUDDLES: sweeping the aim leaves a trail of them).
var _puddles: Array[MeshInstance3D] = []
const MOST_PUDDLES := 40
var _puddle_size := 0.0
var _puddle_age := 0.0
## For tests: held as if the button were.
var button := false
var going := false
var aim := Vector2.ZERO
## Whether it took the stick from him (so it gives it back).
var _took := false


func _ready() -> void:
	_player = get_parent() as Player
	if not InputMap.has_action(&"pee"):
		InputMap.add_action(&"pee")
		var key := InputEventKey.new()
		key.physical_keycode = KEY_V
		InputMap.action_add_event(&"pee", key)
		var pad := InputEventJoypadButton.new()
		pad.button_index = JOY_BUTTON_DPAD_DOWN
		InputMap.action_add_event(&"pee", pad)
	_stream = CPUParticles3D.new()
	_stream.top_level = true
	_stream.emitting = false
	_stream.amount = 48
	_stream.lifetime = 0.55
	_stream.spread = 3.0
	_stream.gravity = Vector3(0.0, -9.8, 0.0)
	_stream.scale_amount_min = 0.7
	_stream.scale_amount_max = 1.0
	var drop := SphereMesh.new()
	drop.radius = 0.008
	drop.height = 0.02
	drop.radial_segments = 6
	drop.rings = 3
	var wet := StandardMaterial3D.new()
	wet.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	wet.albedo_color = Color(1.0, 0.88, 0.25)
	drop.material = wet
	_stream.mesh = drop
	add_child(_stream)
	_splash = CPUParticles3D.new()
	_splash.top_level = true
	_splash.emitting = false
	_splash.amount = 24
	_splash.lifetime = 0.3
	_splash.direction = Vector3.UP
	_splash.spread = 55.0
	_splash.initial_velocity_min = 0.5
	_splash.initial_velocity_max = 1.0
	_splash.gravity = Vector3(0.0, -9.8, 0.0)
	_splash.scale_amount_min = 0.4
	_splash.scale_amount_max = 0.8
	_splash.mesh = drop
	add_child(_splash)


func _physics_process(delta: float) -> void:
	if _rig == null:
		_rig = _player.get_node_or_null(^"Rig") as RaccoonRig
	var free := (_player.takes_input or _took) and not Player.input_blocked
	var held := button or (free and Input.is_action_pressed(&"pee"))
	var level := Vector2(_player.velocity.x, _player.velocity.z).length()
	var scurry := _player.get_node_or_null(^"Scurry") as Scurry
	var can := _player.is_on_floor() and not (scurry and (scurry.held or scurry.climbing))
	going = held and can and (going or level < 0.6)
	# (going, the stick is his aim, not his feet: he stands still)
	if going and not _took and _player.takes_input:
		_player.takes_input = false
		_took = true
	elif not going and _took:
		_player.takes_input = true
		_took = false
	if going:
		_player.velocity.x = 0.0
		_player.velocity.z = 0.0
		var stick := Input.get_vector(&"move_left", &"move_right", &"move_down", &"move_up")
		aim = aim.move_toward(stick, delta * 3.0)
	else:
		aim = aim.move_toward(Vector2.ZERO, delta * 3.0)
	if _rig:
		_rig.peeing = 1.0 if going else 0.0
		_rig.pee_aim = aim
	var flowing := going and _rig != null and _rig._pee_w > 0.8
	_stream.emitting = flowing
	_splash.emitting = false if not flowing else _splash.emitting
	if _rig:
		var size := _rig.global_basis.get_scale().y
		var ahead := _rig.global_basis.z.normalized()
		_stream.global_position = _rig._hips.global_position + ahead * 0.09 * size + Vector3.DOWN * 0.03 * size
		var way := ahead.rotated(Vector3.UP, -aim.x * AIM_TURN)
		_stream.direction = (way + Vector3.UP * lerpf(0.05, 0.45, (aim.y + 1.0) * 0.5)).normalized()
		var push := lerpf(SPEED_NEAR, SPEED_FAR, (aim.y + 1.0) * 0.5)
		_stream.initial_velocity_min = push * 0.95
		_stream.initial_velocity_max = push
	if flowing:
		_wet(delta)
	elif _puddle:
		_puddle_age += delta
		var left := 1.0 - _puddle_age / SOAK
		if left <= 0.0:
			_puddle.queue_free()
			_puddle = null
		else:
			(_puddle.material_override as StandardMaterial3D).albedo_color.a = 0.55 * left


## Where the trickle comes down: its arc stepped out until it meets something.
func _landing() -> Dictionary:
	var space := _player.get_world_3d().direct_space_state
	var at := _stream.global_position
	var speed := _stream.direction * _stream.initial_velocity_max
	for _k in 30:
		var next := at + speed * 0.03
		speed += _stream.gravity * 0.03
		var query := PhysicsRayQueryParameters3D.create(at, next, 1)
		query.exclude = [_player.get_rid()]
		var hit := space.intersect_ray(query)
		if not hit.is_empty():
			return hit
		at = next
	return {}


## The puddle where the trickle lands, spreading while he goes (a new one where it lands somewhere else).
func _wet(delta: float) -> void:
	var hit := _landing()
	if hit.is_empty():
		return
	var at: Vector3 = hit.position
	_splash.global_position = at + (hit.normal as Vector3) * 0.01
	_splash.emitting = true
	# (each puddle stays where it formed; aimed off it, a new one starts there: the user, "aiming shouldn't move the puddle")
	if _puddle == null or _puddle.global_position.distance_to(at) > maxf(_puddle_size * 0.5, 0.06):
		if _puddle:
			_puddle_age = 0.0
		_puddle = MeshInstance3D.new()
		var disc := CylinderMesh.new()
		disc.top_radius = 0.5
		disc.bottom_radius = 0.5
		disc.height = 0.004
		disc.radial_segments = 14
		disc.rings = 1
		_puddle.mesh = disc
		var shine := StandardMaterial3D.new()
		shine.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		shine.albedo_color = Color(0.95, 0.82, 0.3, 0.55)
		shine.roughness = 0.1
		_puddle.material_override = shine
		_puddle.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_player.get_parent().add_child(_puddle)
		_puddles.append(_puddle)
		while _puddles.size() > MOST_PUDDLES:
			var old: MeshInstance3D = _puddles.pop_front()
			if is_instance_valid(old):
				old.queue_free()
		_puddle_size = 0.02
		var up := hit.normal as Vector3
		_puddle.global_transform = Transform3D(Basis(Quaternion(Vector3.UP, up)), at + up * 0.006)
		# (a puddle left behind soaks away by itself)
		get_tree().create_timer(SOAK).timeout.connect(_soak.bind(_puddle))
	_puddle_age = 0.0
	_puddle_size = minf(_puddle_size + delta * 0.08, PUDDLE_MOST)
	_puddle.scale = Vector3(_puddle_size, 1.0, _puddle_size * 0.8)
	(_puddle.material_override as StandardMaterial3D).albedo_color.a = 0.55


func _soak(puddle: MeshInstance3D) -> void:
	if is_instance_valid(puddle) and puddle != _puddle:
		var fade := puddle.create_tween()
		fade.tween_property(puddle.material_override, ^"albedo_color:a", 0.0, 2.0)
		fade.tween_callback(puddle.queue_free)
