class_name RaccoonRig
extends CharacterRig
## The raccoon on the boy's rig. He walks, runs, jumps and climbs as the boy does,
## upright; on top of that, laid over the boy's pose in `_pose_extra`:
##
## - On all fours to duck-walk (ducking or crawling) and to sprint: his back pitched
##   forward, his hands set down flat, a lateral walk when ducking and a bound
##   at a sprint (the user: "mostly upright but he needs all 4 animations for
##   duckwalking and sprinting").
## - His tail (bones tail_0..tail_5): a chain of points on springs, drawn towards a
##   shape for what he is doing and swinging after him, so it follows through.
## - The tail moves (TailMoves, a child of the Player): the spin and the twirl
##   that slows his fall.

const TAIL_BONES := 6
## The spin: how far through it the wind-up ends and the turn is done, and how far round he winds up.
const SPIN_WIND := 0.24
const SPIN_TURNED := 0.72
const SPIN_BACK := 0.75
## Where each foot is in the cycle when it comes down: [hind left, hind right, fore left, fore right].
const WALK_FEET := [0.0, 0.5, 0.25, 0.75]
## Sprinting he bounds: both hind feet push off nearly together, he flies stretched out, lands on both
## fore paws, and gathers his hind feet up under him (the user: "more of a bounding leap").
const BOUND_FEET := [0.0, 0.04, 0.5, 0.54]

## The tail's shapes, as each segment's angle below straight back (radians), in the hips' own space.
const TAIL_STAND := [0.95, 0.55, 0.15, -0.25, -0.6, -0.85]
const TAIL_RUN := [0.25, 0.05, -0.08, -0.12, -0.12, -0.1]
const TAIL_QUAD := [0.45, 0.55, 0.62, 0.62, 0.55, 0.45]  # (his hips are pitched well forward on all fours: this is back and a little up)

var _tail: Array[Node3D] = []
var _tail_dir: Array[Vector3] = []
var _tail_len: Array[float] = []
var _points := PackedVector3Array()
var _speeds := PackedVector3Array()
var _moves: Node

var _quad := 0.0
var _gallop := 0.0
var _qphase := 0.0
var _glide := 0.0
var _twirl := 0.0
var _spin_w := 0.0
## Jumped from all fours he stays on them in the air (the user: "he needs an all 4s jumping animation"): whether
## this jump is one, and how far into that pose he is.
var _leaping := false
var _leap_w := 0.0
var _leap_rise := 0.0


func _init() -> void:
	if model == null:
		model = preload("res://models/raccoon.glb")


func _ready() -> void:
	super()
	var parent := _hips
	for k in TAIL_BONES:
		var bone := "tail_%d" % k
		var joint := _joint(parent, bone, _rest(bone))
		_tail.append(joint)
		parent = joint
	for k in TAIL_BONES:
		# (each segment runs to the next joint; the last is as long as the one before)
		var to_next := _rest("tail_%d" % (k + 1)) if k + 1 < TAIL_BONES else _rest("tail_%d" % k)
		_tail_dir.append(to_next.normalized())
		_tail_len.append(to_next.length())
	_points.resize(TAIL_BONES + 1)
	_speeds.resize(TAIL_BONES + 1)
	if _player:
		_moves = _player.get_node_or_null(^"TailMoves")
		if _player.has_signal(&"jumped"):
			_player.jumped.connect(func() -> void: _leaping = _quad > 0.5 and _gallop > 0.3)


func _pose_extra(delta: float) -> void:
	var velocity: Vector3 = _player.velocity
	var flat := Vector3(velocity.x, 0.0, velocity.z)
	var speed := flat.length()
	var free: bool = not (&"state" in _player) or _player.state == Player.State.FREE
	var low: bool = (&"is_ducking" in _player and _player.is_ducking) or (&"is_crawling" in _player and _player.is_crawling)
	# (he runs on all fours, bounding: anything over a walk; the user, 2026-11-01: "remove the sprint button he
	# should just run on all 4s")
	var fast: bool = speed > _player.walk_speed * 1.25 and not low
	var busy := maxf(maxf(_ball, _roll), maxf(_sprawled, _three)) + _carry + smoothstep(0.0, 0.1, _sit_at) + _slide
	var grounded: bool = _player.is_on_floor()
	if grounded and _air < 0.2 and velocity.y <= 0.0:
		_leaping = false
	if _moves and (_moves.gliding or _moves.spin < 1.0):
		_leaping = false
	_leap_w = _approach(_leap_w, 1.0 if _leaping and not grounded else 0.0, 12.0, delta)
	_leap_rise = clampf(velocity.y / 6.0, -1.0, 1.0)
	var wanted := 1.0 if free and (((low or fast) and _air < 0.5) or _leaping) and busy < 0.2 else 0.0
	_quad = _approach(_quad, wanted, 7.0, delta)
	_gallop = _approach(_gallop, smoothstep(_player.walk_speed, _player.run_speed * 0.8, speed) if fast else 0.0, 6.0, delta)
	var stride := lerpf(0.44, 1.9, _gallop)
	_qphase = fposmod(_qphase + speed / stride * delta, 1.0)

	var spin := 1.0
	var gliding := false
	if _moves:
		spin = _moves.spin
		gliding = _moves.gliding
	_glide = _approach(_glide, 1.0 if gliding else 0.0, 10.0, delta)
	_twirl = fposmod(_twirl + delta * TAU * 2.4 * _glide, TAU)
	_spin_w = _approach(_spin_w, 1.0 if spin < 1.0 else 0.0, 30.0, delta)

	if _quad > 0.002:
		_pose_quad(smoothstep(0.0, 1.0, _quad), speed, stride)
	if _glide > 0.002:
		_pose_glide(_glide)
	if _spin_w > 0.002:
		_pose_spin(spin, _spin_w)
	_pose_tail(delta, speed, spin)


## The spin (the tail button): he crouches and winds up turned to his right, then whips round once to the left, fast
## at first and settling, arms flung out, the tail lashing after him; and comes up out of it (the user: "the spin
## needs to be snappier and he shouldnt just rotate he needs to crouch and animate in to the spin and whip his tail").
func _pose_spin(at: float, w: float) -> void:
	var crouch := smoothstep(0.0, SPIN_WIND, at) * (1.0 - smoothstep(SPIN_TURNED, 1.0, at))
	var yaw := 0.0
	if at < SPIN_WIND:
		yaw = -SPIN_BACK * smoothstep(0.0, SPIN_WIND, at)
	elif at < SPIN_TURNED:
		var s := (at - SPIN_WIND) / (SPIN_TURNED - SPIN_WIND)
		yaw = -SPIN_BACK + (TAU + SPIN_BACK) * (1.0 - pow(1.0 - s, 3.0))
	_hips.position.y -= 0.09 * crouch * w
	_hips.basis = Basis(Vector3.UP, yaw * w) * _hips.basis
	_spine.basis = _slerp(_spine.basis, Basis(Vector3.RIGHT, 0.35) * _spine.basis, crouch * w)
	_head.basis = _slerp(_head.basis, Basis(Vector3.RIGHT, -0.3) * _head.basis, crouch * w)
	# Arms in to the chest winding up, flung wide as he goes round
	var fling := smoothstep(SPIN_WIND, SPIN_WIND + 0.1, at) * (1.0 - smoothstep(SPIN_TURNED, 1.0, at))
	var turned := Basis(Vector3.UP, yaw * w)
	for i in 2:
		var side := 1.0 if i == 0 else -1.0
		var tucked := Vector3(side * 0.12, 0.5, 0.16)
		var wide := Vector3(side * 0.5, 0.56, -0.04)
		var hand := turned * tucked.lerp(wide, fling) + Vector3.DOWN * 0.09 * crouch
		_solve_arm(i, side, to_global(hand), _forearm, w * maxf(crouch, fling))


## On all fours, by `w`.
func _pose_quad(w: float, speed: float, stride: float) -> void:
	var moving := clampf(speed / 0.5, 0.0, 1.0)
	var cycle := TAU * _qphase
	var bounding := moving * _gallop
	# (bounding, he is thrown up and forward off his hind feet, and hops up a little again off his fore paws)
	var flight := _bump(_qphase, 0.22, 0.6) * 0.15 + _bump(fposmod(_qphase - 0.72, 1.0), 0.0, 0.32) * 0.05
	var hips_y := _hip_height * lerpf(0.72, 0.77, _gallop) + sin(2.0 * cycle) * 0.01 * moving * (1.0 - _gallop) + flight * bounding
	# (rump up, shoulders down, as a raccoon goes: his arms are short)
	# (bounding, his back stretches out flat in the air and rounds as his hind feet come up under him)
	var lean := lerpf(1.82, 1.75, _gallop) + cos(TAU * (_qphase - 0.9)) * 0.22 * bounding
	# Leaping: stretched out flat going up, rump dropping and front reaching down coming down
	var up := clampf(_leap_rise, 0.0, 1.0)
	var down := clampf(-_leap_rise, 0.0, 1.0)
	hips_y = lerpf(hips_y, _hip_height * (0.8 - 0.06 * down), _leap_w)
	lean = lerpf(lean, 1.5 - 0.1 * up + 0.25 * down, _leap_w)

	# Where the boy's pose had his feet, in the rig's space, before the hips move.
	var base_feet: Array[Transform3D] = []
	for i in 2:
		base_feet.append(_hips.transform * _feet[i].transform)

	_hips.position = _hips.position.lerp(Vector3(0.0, hips_y, -0.03), w)
	_hips.basis = _slerp(_hips.basis, Basis(Vector3.RIGHT, lean * 0.48), w)
	_spine.basis = _slerp(_spine.basis, Basis(Vector3.RIGHT, lean * 0.33), w)
	if _chest:
		_chest.basis = _slerp(_chest.basis, Basis(Vector3.RIGHT, lean * 0.19), w)
	if _neck:
		_neck.basis = _slerp(_neck.basis, Basis(Vector3.RIGHT, -lean * 0.45), w)
	_head.basis = _slerp(_head.basis, Basis(Vector3.RIGHT, -lean * 0.55 + 0.04 + sin(cycle * 2.0) * 0.04 * moving), w)

	var duty := lerpf(0.66, 0.3, _gallop)
	var half := duty * stride * 0.5 * moving
	var lift := lerpf(0.05, 0.16, _gallop) * moving
	var hips_inverse := _hips.transform.affine_inverse()
	# Hind feet, under the hips
	for i in 2:
		var side := 1.0 if i == 0 else -1.0
		var at := fposmod(_qphase - lerpf(WALK_FEET[i], BOUND_FEET[i], _gallop), 1.0)
		var step := _cycle(at, duty, half, lift)
		# (flung out behind him as he leaves the ground)
		step.x -= _bump(at, duty - 0.02, 0.62) * 0.16 * bounding
		var point := Vector3(side * 0.095, ANKLE + step.y, -0.07 + step.x)
		# (in a leap: flung out behind going up, drawn up under him coming down)
		point = point.lerp(Vector3(side * 0.1, ANKLE + 0.14 + 0.08 * up - 0.04 * down, -0.36 * up + 0.04 * down - 0.08), _leap_w)
		var pitch := step.y / maxf(lift, 0.001) * 0.6 if at >= duty else 0.0
		var wanted := Transform3D(Basis(Vector3.RIGHT, pitch), point)
		var blended := base_feet[i].interpolate_with(wanted, w)
		_solve_leg(i, side, hips_inverse * blended.origin, _hips.basis.inverse() * blended.basis.orthonormalized())
	# Fore paws, set down flat under the shoulders
	for i in 2:
		var side := 1.0 if i == 0 else -1.0
		var at := fposmod(_qphase - lerpf(WALK_FEET[i + 2], BOUND_FEET[i + 2], _gallop), 1.0)
		var step := _cycle(at, duty, half, lift * 0.9)
		# (reaching out ahead for the ground, and swept back as he gathers)
		step.x += (_bump(at, 0.68, 1.0) * 0.14 - _bump(at, duty - 0.02, 0.55) * 0.08) * bounding
		var shoulder := to_local(_shoulders[i].global_position)
		var fingers := (global_basis * Vector3(-side * 0.12, 0.0, 1.0)).normalized()
		var point := Vector3(side * 0.13, 0.03 + step.y, shoulder.z + 0.05 + step.x)
		# (in a leap: reaching out ahead, and down for the ground coming down)
		point = point.lerp(Vector3(side * 0.12, 0.16 - 0.12 * down, shoulder.z + 0.28 - 0.06 * down), _leap_w)
		var pole := (global_basis * Vector3(side * 0.3, 0.0, -1.0)).normalized()
		_solve_arm(i, side, to_global(point) - fingers * 0.03, _forearm, w, pole)
		_lay_hand(i, side, Vector3.UP, fingers, w * (1.0 - 0.6 * clampf(step.y / maxf(lift, 0.001), 0.0, 1.0)))


## 0 outside a..b, rising to 1 halfway between and back down.
static func _bump(x: float, a: float, b: float) -> float:
	return sin(PI * clampf((x - a) / (b - a), 0.0, 1.0))


## Where a foot is through one cycle: (how far ahead of its middle, how high).
## Down for the first `duty` of it, going back under him; then lifted and brought forward.
static func _cycle(at: float, duty: float, half: float, lift: float) -> Vector2:
	if at < duty:
		return Vector2(half - 2.0 * half * at / duty, 0.0)
	var s := (at - duty) / (1.0 - duty)
	return Vector2(-half + 2.0 * half * (0.5 - 0.5 * cos(PI * s)), sin(PI * s) * lift)


## Twirling his tail over his head to come down slowly: arms out, legs hanging.
func _pose_glide(w: float) -> void:
	for i in 2:
		var side := 1.0 if i == 0 else -1.0
		var bob := sin(_twirl * 2.0 + side) * 0.03
		_solve_arm(i, side, to_global(Vector3(side * 0.52, 0.86 + bob, 0.04)), _forearm, w)
	_head.basis = _slerp(_head.basis, Basis(Vector3.RIGHT, -0.25), w * 0.7)


## The tail's shape for now, in the hips' space, as a direction for each segment.
func _tail_shape(speed: float, spin: float) -> Array[Vector3]:
	var run := clampf(speed / 3.0, 0.0, 1.0)
	var wag := sin(_time * 2.1) * 0.25 * (1.0 - run) + sin(TAU * _phase) * 0.12 * run
	var dirs: Array[Vector3] = []
	for k in TAIL_BONES:
		var down: float = lerpf(lerpf(TAIL_STAND[k], TAIL_RUN[k], run), TAIL_QUAD[k], _quad)
		down += sin(_time * 1.3 - k * 0.6) * 0.06 * (1.0 - run)
		var across := wag * (0.4 + 0.15 * k)
		dirs.append(Vector3(sin(across) * cos(down), -sin(down), -cos(across) * cos(down)).normalized())
	if _glide > 0.001:
		# Whirled round like a propeller on a cone leaning up and back from its root,
		# clear of his head; each segment a little behind the one before.
		var axis := Vector3(0.0, 1.0, -0.55).normalized()
		var u := Vector3.RIGHT
		var v := axis.cross(u)
		for k in TAIL_BONES:
			var angle := _twirl - k * 0.22
			var out := 0.25 + 0.06 * k
			dirs[k] = dirs[k].slerp((axis * cos(out) + (u * cos(angle) + v * sin(angle)) * sin(out)).normalized(), _glide)
	if _spin_w > 0.001 and spin < 1.0:
		# Wound round to his left side as he crouches; then flung out straight behind as he whips round, the springs
		# letting it lag and then lash out after him.
		var wound := smoothstep(0.0, SPIN_WIND, spin) * (1.0 - smoothstep(SPIN_WIND, SPIN_WIND + 0.12, spin))
		for k in TAIL_BONES:
			var angle := PI - (1.7 + 0.12 * k) * wound
			dirs[k] = dirs[k].slerp(Vector3(sin(angle), 0.1 + 0.05 * wound, cos(angle)).normalized(), _spin_w)
	return dirs


func _pose_tail(delta: float, speed: float, spin: float) -> void:
	var dirs := _tail_shape(speed, spin)
	var hips := _hips.global_transform
	var size := global_basis.get_scale().y
	var root := _tail[0].global_position
	var targets := PackedVector3Array([root])
	for k in TAIL_BONES:
		targets.append(targets[k] + (hips.basis.orthonormalized() * dirs[k]) * _tail_len[k] * size)
	var fresh := _points[0].distance_to(root) > 2.0 or _points[TAIL_BONES] == Vector3.ZERO
	# (not stiffened for the spin: its lag is the whip)
	var snap := _glide
	var steps := 2
	var dt := delta / steps
	for _s in steps:
		_points[0] = root
		for k in range(1, TAIL_BONES + 1):
			if fresh:
				_points[k] = targets[k]
				_speeds[k] = Vector3.ZERO
				continue
			var stiff := lerpf(300.0, 110.0, float(k) / TAIL_BONES) * (1.0 + 2.5 * snap)
			var accel := (targets[k] - _points[k]) * stiff - _speeds[k] * 15.0 + Vector3.DOWN * 2.5
			_speeds[k] += accel * dt
			_points[k] += _speeds[k] * dt
			# (whirled, it is held to its cone: on springs alone it is flung out wide)
			_points[k] = _points[k].lerp(targets[k], 0.5 * _glide)
		# (each segment keeps its length)
		for k in range(1, TAIL_BONES + 1):
			var span := _points[k] - _points[k - 1]
			var length := _tail_len[k - 1] * size
			_points[k] = _points[k - 1] + (span.normalized() if span.length_squared() > 0.000001 else hips.basis.z * -1.0) * length
	for k in TAIL_BONES:
		var joint := _tail[k]
		var parent := (joint.get_parent() as Node3D).global_basis.orthonormalized()
		var want := parent.inverse() * (_points[k + 1] - _points[k]).normalized()
		joint.basis = Basis(Quaternion(_tail_dir[k], want.normalized()))


static func _slerp(from: Basis, to: Basis, w: float) -> Basis:
	return Basis(from.orthonormalized().get_rotation_quaternion().slerp(to.orthonormalized().get_rotation_quaternion(), w))
