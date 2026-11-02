class_name CloudDust
extends Node3D
## A child of the Player: dust kicked up as little 3D cloud blobs, puffing up, drifting and shrinking away (the user,
## 2026-11-01: "your foot dust particles should be 3d cloud blobs rather than just simple star texture"). In place
## of the rig's own dust (its `dusty` is off). A few puffs exactly where each foot comes down at a run (the user:
## "the smoke dust needs to spawn exactly on every step not just a generic trail, and it should be a few puffs"):
## each paw on all fours (RaccoonRig.stepped), each foot upright; a ring on landing; a trail sliding; a ring spinning.

const BLOBS := 40
const LIFE := 0.55

var _player: Player
var _blobs: Array[MeshInstance3D] = []
var _born: Array[float] = []
var _drift: Array[Vector3] = []
var _size: Array[float] = []
var _next := 0
var _clock := 0.0
var _step := 0.0
var _planted_was: Array[bool] = [true, true]


func _ready() -> void:
	_player = get_parent() as Player
	top_level = true
	var blob := SphereMesh.new()
	blob.radius = 0.5
	blob.height = 1.0
	blob.radial_segments = 8
	blob.rings = 5
	var material := Toon.surface(Color(0.93, 0.89, 0.82))
	for k in BLOBS:
		var part := MeshInstance3D.new()
		part.mesh = blob
		part.material_override = material
		part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		part.visible = false
		add_child(part)
		_blobs.append(part)
		_born.append(-10.0)
		_drift.append(Vector3.ZERO)
		_size.append(0.1)
	var rig := _player.get_node_or_null(^"Rig")
	if rig and rig.has_signal(&"stepped"):
		rig.stepped.connect(_footfall)
	_player.landed.connect(func(impact: float) -> void:
		if impact > 3.0:
			_ring(clampi(int(impact * 0.8), 4, 9), 0.25 + impact * 0.02, 0.09 + impact * 0.006))


## A puff of one blob at `at`, drifting `drift` (m/s), this big at its fullest.
func puff(at: Vector3, drift: Vector3, size: float) -> void:
	var k := _next
	_next = (_next + 1) % BLOBS
	_blobs[k].global_position = at
	_born[k] = _clock
	_drift[k] = drift
	_size[k] = size * randf_range(0.8, 1.2)
	_blobs[k].visible = true


## A few puffs where a foot came down, kicked back and up a little; bigger the faster he goes.
func _footfall(at: Vector3) -> void:
	var flat := Vector3(_player.velocity.x, 0.0, _player.velocity.z)
	var speed := flat.length()
	if speed < 1.2 or not _player.is_on_floor():
		return
	var behind := -flat.normalized()
	var size := clampf(0.05 + speed * 0.011, 0.06, 0.13)
	for k in 3:
		var aside := Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0)) * 0.07
		puff(at + Vector3.UP * 0.04 + aside, behind * randf_range(0.3, 0.8) + aside * 3.0 + Vector3.UP * randf_range(0.25, 0.5), size)


func _ring(count: int, speed: float, size: float) -> void:
	var feet := _player.global_position + Vector3.UP * 0.06
	for k in count:
		var a := TAU * k / count + randf() * 0.4
		var out := Vector3(cos(a), 0.0, sin(a))
		puff(feet + out * 0.2, out * speed * 2.0 + Vector3.UP * 0.25, size)


func _process(delta: float) -> void:
	_clock += delta
	var flat := Vector2(_player.velocity.x, _player.velocity.z).length()
	var on_ground := _player.is_on_floor()
	# Upright, at each footfall of his own (the rig says when a foot is set down)
	var rig := _player.get_node_or_null(^"Rig")
	if rig and rig.has_method(&"is_planted") and on_ground and flat > 1.6 and float(rig.get(&"_quad")) < 0.5:
		for i in 2:
			var down: bool = rig.is_planted(i)
			if down and not _planted_was[i]:
				_footfall(rig.foot_position(i))
			_planted_was[i] = down
	# A trail sliding, a ring spinning
	var rate := 0.0
	if _player.state == Player.State.SLIDE:
		rate = 16.0
	var moves := _player.get_node_or_null(^"TailMoves") as TailMoves
	var spinning := moves != null and moves.spin < 1.0 and on_ground
	if spinning:
		rate = 18.0
	_step += rate * delta
	while _step >= 1.0:
		_step -= 1.0
		var behind := -Vector3(_player.velocity.x, 0.0, _player.velocity.z).normalized() if flat > 0.1 else Vector3.ZERO
		var aside := Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0)) * 0.12
		if spinning:
			var a := randf() * TAU
			aside = Vector3(cos(a), 0.0, sin(a)) * 0.35
			behind = aside * 2.0
		puff(_player.global_position + Vector3.UP * 0.05 + behind * 0.25 + aside, behind * 0.6 + Vector3.UP * 0.35, 0.08)
	for k in BLOBS:
		if not _blobs[k].visible:
			continue
		var age := (_clock - _born[k]) / LIFE
		if age >= 1.0:
			_blobs[k].visible = false
			continue
		# (puffs up fast, then shrinks away as it drifts and slows)
		var grown := smoothstep(0.0, 0.18, age) * (1.0 - smoothstep(0.45, 1.0, age))
		_blobs[k].global_position += _drift[k] * delta * (1.0 - age)
		_blobs[k].scale = Vector3(1.0, 0.8, 1.0) * maxf(_size[k] * grown, 0.001)
