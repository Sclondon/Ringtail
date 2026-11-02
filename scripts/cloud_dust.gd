class_name CloudDust
extends Node3D
## A child of the Player: dust kicked up as little 3D cloud blobs, puffing up, drifting and shrinking away (the user,
## 2026-11-01: "your foot dust particles should be 3d cloud blobs rather than just simple star texture"). In place
## of the rig's own dust (its `dusty` is off). A few puffs exactly where each foot comes down at a run (the user:
## "the smoke dust needs to spawn exactly on every step not just a generic trail, and it should be a few puffs"):
## each paw on all fours (RaccoonRig.stepped), each foot upright; a ring on landing; a trail sliding; a ring spinning.

const BLOBS := 140
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
	var clusters: Array[Mesh] = []
	for v in 4:
		clusters.append(_cluster(v))
	var material := Toon.surface(Color(0.93, 0.89, 0.82))
	for k in BLOBS:
		var part := MeshInstance3D.new()
		part.mesh = clusters[k % clusters.size()]
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


## A little cloud: a lump of a few balls of different sizes, flat along the ground (the user, 2026-11-02: "shouldnt
## just be a perfect sphere, but a cluster of them like a little clouds"). About 1 m across before scaling, its
## bottom at 0.
static func _cluster(variant: int) -> Mesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7 + variant * 31
	var ball := SphereMesh.new()
	ball.radius = 0.5
	ball.height = 1.0
	ball.radial_segments = 8
	ball.rings = 5
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var lumps := 4 + variant % 2
	for i in lumps:
		var a := TAU * i / lumps + rng.randf_range(-0.4, 0.4)
		var r := 0.0 if i == 0 else rng.randf_range(0.22, 0.32)
		var size := 0.62 if i == 0 else rng.randf_range(0.34, 0.48)
		var at := Vector3(cos(a) * r, size * 0.5, sin(a) * r)
		tool.append_from(ball, 0, Transform3D(Basis.from_scale(Vector3.ONE * size), at))
	tool.generate_normals()
	return tool.commit()


## A puff of one little cloud at `at` (its bottom), drifting `drift` (m/s), this big at its fullest.
func puff(at: Vector3, drift: Vector3, size: float) -> void:
	var k := _next
	_next = (_next + 1) % BLOBS
	_blobs[k].global_position = at
	_blobs[k].rotation.y = randf() * TAU
	_born[k] = _clock
	_drift[k] = drift
	_size[k] = size * randf_range(0.8, 1.2)
	_blobs[k].visible = true


## A little ring of puffs on the ground round where a foot came down, spreading out (the user, 2026-11-02: "it
## should spawn in little rings where you step"); bigger the faster he goes.
func _footfall(at: Vector3) -> void:
	var flat := Vector3(_player.velocity.x, 0.0, _player.velocity.z)
	var speed := flat.length()
	if speed < 1.2 or not _player.is_on_floor():
		return
	# (on the ground he stands on, not at the foot's height: "the dust particles spawn above the ground")
	at.y = _player.global_position.y
	var size := clampf(0.04 + speed * 0.008, 0.05, 0.1)
	var count := 5
	for k in count:
		var a := TAU * k / count + randf() * 0.5
		var out := Vector3(cos(a), 0.0, sin(a))
		puff(at + out * 0.05, out * randf_range(0.45, 0.7) + Vector3.UP * 0.08, size)


func _ring(count: int, speed: float, size: float) -> void:
	var feet := _player.global_position
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
	# (only while the tail sweeps round: not during the crouch and wind-up before it)
	# (no ring of dust as he spins: the tail leaves its trail instead; the user, 2026-11-02)
	var spinning := false
	_step += rate * delta
	while _step >= 1.0:
		_step -= 1.0
		var behind := -Vector3(_player.velocity.x, 0.0, _player.velocity.z).normalized() if flat > 0.1 else Vector3.ZERO
		var aside := Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0)) * 0.12
		if spinning:
			var a := randf() * TAU
			aside = Vector3(cos(a), 0.0, sin(a)) * 0.35
			behind = aside * 2.0
		puff(_player.global_position + behind * 0.25 + aside, behind * 0.6 + Vector3.UP * 0.35, 0.08)
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
		_blobs[k].scale = Vector3(1.0, 0.7, 1.0) * maxf(_size[k] * grown, 0.001)
