class_name RaccoonRig
extends CharacterRig

## A paw came down (on all fours: each of the four; upright, CloudDust watches the rig's own feet), where in the world.
signal stepped(at: Vector3)
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
const SPIN_WIND := 0.22
const SPIN_TURNED := 0.8
const SPIN_BACK := 0.7
## Where each foot is in the cycle when it comes down: [hind left, hind right, fore left, fore right].
const WALK_FEET := [0.0, 0.5, 0.25, 0.75]
## Sprinting he bounds: both hind feet push off nearly together, he flies stretched out, lands on both
## fore paws, and gathers his hind feet up under him (the user: "more of a bounding leap").
const BOUND_FEET := [0.0, 0.04, 0.5, 0.54]

## The tail's shapes, as each segment's angle below straight back (radians), in the hips' own space.
const TAIL_STAND := [0.95, 0.55, 0.15, -0.25, -0.6, -0.85]
const TAIL_RUN := [0.25, 0.05, -0.08, -0.12, -0.12, -0.1]
const TAIL_QUAD := [0.45, 0.55, 0.62, 0.62, 0.55, 0.45]  # (his hips are pitched well forward on all fours: this is back and a little up)
## The shapes this rig uses (a figure on it, such as the cat, gives its own).
var tail_stand: Array = TAIL_STAND
var tail_run: Array = TAIL_RUN
var tail_quad: Array = TAIL_QUAD
## On all fours whenever it is on the ground, not only to duck or run (the cat).
var always_on_fours := false

## Where the rotor starts: the segments before it go up his back, the rest whirl over his head.
const ROTOR_FROM := 4
## How much longer his tail is drawn out as he twirls it.
const ROTOR_STRETCH := 1.2
## How much longer it is drawn out, held stiff, as he spins.
const SPIN_STRETCH := 1.35
## The fur's springs (see _spring_fur), and which region his head is.
const FUR_STIFFNESS := 200.0
const FUR_DAMPING := 8.0
const FUR_HEAD := 16
## The fur shader's vertex stage, added to Toon's: a point tagged as a spike is moved by its region's lag, flex
## squared. Tagged in Blender as UV2 (region, -flex - 0.001), it arrives flipped as glTF has it, (region, 1.001 + flex);
## every other point's arrives at most 1.
const FUR_VERTEX := """
// (the grit baked into his vertex colours: tools/build_raccoon.py paint_grit, written over this)
const float GRIT_SCALE = 1.3;
uniform vec3 lags[17];
void vertex() {
	if (UV2.y > 1.0005) {
		float flex = UV2.y - 1.001;
		int region = clamp(int(UV2.x + 0.5), 0, 16);
		VERTEX += lags[region] * flex * flex;
	}
}
"""

var _sniff := 0.0
var _sniff_at := 1.0
var _sniff_wait := 4.0
var _fur_mesh: MeshInstance3D
var _fur_materials: Array[ShaderMaterial] = []
var _fur_lag := PackedVector3Array()
var _fur_lag_speed := PackedVector3Array()
var _fur_seen := PackedVector3Array()
var _fur_speed_was := PackedVector3Array()
var _fur_uniform := PackedVector3Array()
var _rotor_disc: MeshInstance3D
var _rotor_puffs: CPUParticles3D
var _swoosh_puffs: CPUParticles3D
var _lids: Array[Node3D] = []
var _brows: Array[Node3D] = []
var _brow_rest: Array[Vector3] = []
var _ears: Array[Node3D] = []
var _face: Array = []
var _face_now: StringName = &"neutral"
var _face_left := 0.0
var _blink_wait := 2.0
var _blink_at := 1.0
var _hearts_were := 3
var _caps_were := 0

var _tail: Array[Node3D] = []
var _tail_dir: Array[Vector3] = []
var _tail_len: Array[float] = []
var _points := PackedVector3Array()
var _speeds := PackedVector3Array()
var _moves: Node
var _scurry: Node
var _climb_w := 0.0
var _leg_swing := 0.0
var _leg_swing_speed := 0.0
var _spin_jump: Node
var _tj_w := 0.0
var _tj_turn := 0.0
var _paw_was: Array[float] = [0.0, 0.0, 0.0, 0.0]

var _quad := 0.0
var _gallop := 0.0
var _qphase := 0.0
var _glide := 0.0
var _twirl := 0.0
var _spin_w := 0.0
## Where the spin has him turned, and how far the tail swings back behind him for how fast he turns.
var _spin_yaw := 0.0
var _spin_trail := 0.0
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
		_scurry = _player.get_node_or_null(^"Scurry")
		_spin_jump = _player.get_node_or_null(^"SpinJump")
		if _player.has_signal(&"jumped"):
			_player.jumped.connect(func() -> void: _leaping = _quad > 0.5 and (_gallop > 0.3 or always_on_fours))
	_make_fur()
	_build_face()


func _pose_extra(delta: float) -> void:
	var velocity: Vector3 = _player.velocity
	var flat := Vector3(velocity.x, 0.0, velocity.z)
	var speed := flat.length()
	var free: bool = not (&"state" in _player) or _player.state == Player.State.FREE
	# (ducking, crawling and scurrying he is on all fours: the user, 2026-11-01, "why is duck not on all 4s?")
	var low: bool = (&"is_ducking" in _player and _player.is_ducking) or (&"is_crawling" in _player and _player.is_crawling)
	var scurrying: bool = _scurry != null and _scurry.held
	var climbing: bool = _scurry != null and _scurry.climbing
	_climb_w = _approach(_climb_w, 1.0 if climbing else 0.0, 10.0, delta)
	if climbing:
		speed = absf(velocity.y)
	# (he runs on all fours, bounding, with the stick pushed all the way, which sprints him: the user, 2026-11-01,
	# "remove the sprint button he should just run on all 4s", then "he should only run on all 4s if you stick the
	# joystick all the way"; raccoon.tscn sprints on a full push at once)
	var sprinting: bool = &"is_sprinting" in _player and _player.is_sprinting
	var fast: bool = speed > _player.walk_speed * 1.25 and not low and (sprinting or scurrying or always_on_fours)
	var busy := maxf(maxf(_ball, _roll), maxf(_sprawled, _three)) + _carry + smoothstep(0.0, 0.1, _sit_at) + _slide
	var grounded: bool = _player.is_on_floor()
	if grounded and _air < 0.2 and velocity.y <= 0.0:
		_leaping = false
	if _moves and (_moves.gliding or _moves.spin < 1.0):
		_leaping = false
	_leap_w = _approach(_leap_w, 1.0 if _leaping and not grounded else 0.0, 12.0, delta)
	_leap_rise = clampf(velocity.y / 6.0, -1.0, 1.0)
	var wanted := 1.0 if free and (((low or fast or scurrying or always_on_fours) and _air < 0.5) or _leaping or climbing) and busy < 0.2 else 0.0
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
	_twirl = fposmod(_twirl + delta * TAU * 3.5 * _glide, TAU)
	_spin_w = _approach(_spin_w, 1.0 if spin < 1.0 else 0.0, 30.0, delta)

	if _quad > 0.002:
		_pose_quad(smoothstep(0.0, 1.0, _quad), speed, stride)
	if _climb_w > 0.002:
		_pose_climb(_climb_w)
	if _hang > 0.3:
		_pose_hang_swing(delta)
	if _glide > 0.002:
		_pose_glide(_glide)
	if _spin_w > 0.002:
		_pose_spin(spin, _spin_w)
	# The spin jump: round and round in the air, arms out, the tail stiff (SpinJump)
	var twirling: bool = _spin_jump != null and _spin_jump.twirling
	_tj_w = _approach(_tj_w, 1.0 if twirling else 0.0, 14.0, delta)
	if _tj_w > 0.002:
		_tj_turn = fposmod(_tj_turn + delta * 22.0 * _tj_w, TAU)
		_hips.basis = Basis(Vector3.UP, _tj_turn * _tj_w) * _hips.basis
		for i in 2:
			var side := 1.0 if i == 0 else -1.0
			_solve_arm(i, side, to_global(Basis(Vector3.UP, _tj_turn) * Vector3(side * 0.48, 0.62, 0.0)), _forearm, _tj_w)
	_sniffing(delta, speed)
	_pose_face(delta, speed)
	_pose_tail(delta, speed, spin)
	_spring_fur(delta)
	_swoosh(spin)


## His face: lids that blink and set his look, brows and ears (the user: "his eyes need to be animated and he
## needs a few expressions"). Each expression is [lid (how far rolled down: -1.5 wide open .. 1.5 shut), lid tilt
## (inner corners down), brow raise (m), brow tilt (inner ends down), ears (forward up, back down), ear droop].
const FACES := {
	&"neutral": [-1.3, 0.0, 0.0, 0.0, 0.0, 0.0],
	&"happy": [-0.25, -0.45, 0.022, -0.3, 0.3, 0.0],
	&"determined": [-0.35, 0.6, -0.018, 0.6, -0.45, 0.0],
	&"surprised": [-1.65, 0.0, 0.04, -0.2, 0.45, 0.0],
	&"hurt": [1.35, -0.2, 0.004, -0.4, -0.7, 0.2],
	&"sleepy": [-0.15, 0.0, -0.004, 0.0, -0.2, 0.45],
	&"sniff": [-0.6, 0.0, 0.006, 0.0, 0.4, 0.0],
}


## Sets an expression for a while (over whatever he would show otherwise).
func express(face: StringName, seconds := 1.2) -> void:
	_face_now = face
	_face_left = seconds


func _build_face() -> void:
	for suffix: String in ["_l", "_r"]:
		var side := 1 if suffix == "_l" else -1
		if _has("lid" + suffix):
			_lids.append(_joint(_head, "lid" + suffix, _rest("lid" + suffix)))
		if _has("brow" + suffix):
			var brow := _joint(_head, "brow" + suffix, _rest("brow" + suffix))
			_brows.append(brow)
			_brow_rest.append(brow.position)
		if _has("ear" + suffix):
			_ears.append(_joint(_head, "ear" + suffix, _rest("ear" + suffix)))
	_face = (FACES[&"neutral"] as Array).duplicate()
	# (hurt when he loses a heart, pleased with a Bottlecap)
	var game := get_tree().get_first_node_in_group(&"game") if is_inside_tree() else null
	if game and game.has_signal(&"hearts_changed"):
		game.hearts_changed.connect(func(count: int) -> void:
			if count < _hearts_were:
				express(&"hurt", 0.9)
			_hearts_were = count)
		game.caps_changed.connect(func(count: int, _total: int) -> void:
			if count > _caps_were:
				express(&"happy", 2.5)
			_caps_were = count)


func _pose_face(delta: float, speed: float) -> void:
	if _lids.is_empty() and _brows.is_empty() and _ears.is_empty():
		return
	_face_left -= delta
	var wanted: StringName = &"neutral"
	if _face_left > 0.0:
		wanted = _face_now
	elif _spin_w > 0.3 or (_gallop > 0.6 and speed > 3.0):
		wanted = &"determined"
	elif _player.velocity.y < -7.0 and _air > 0.9:
		wanted = &"surprised"
	elif _sit_at > 0.3:
		wanted = &"sleepy"
	elif _sniff > 0.3:
		wanted = &"sniff"
	var target: Array = FACES[wanted]
	for k in _face.size():
		_face[k] = _approach(_face[k], target[k], 9.0, delta)
	# Blinking: every few seconds, now and then twice; shut tight asleep
	_blink_wait -= delta
	if _blink_wait <= 0.0:
		_blink_at = 0.0
		_blink_wait = randf_range(1.8, 5.5) if randf() > 0.2 else 0.25
	_blink_at = minf(_blink_at + delta / 0.16, 1.0)
	var blink := sin(PI * _blink_at) if _blink_at < 1.0 else 0.0
	var lid: float = lerpf(_face[0], 1.5, maxf(blink, smoothstep(0.3, 0.8, _lie_at)))
	for i in _lids.size():
		var side := 1.0 if i == 0 else -1.0
		_lids[i].basis = Basis(Vector3.BACK, -side * _face[1]) * Basis(Vector3.RIGHT, lid)
	for i in _brows.size():
		var side := 1.0 if i == 0 else -1.0
		_brows[i].position = _brow_rest[i] + Vector3.UP * _face[2]
		_brows[i].basis = Basis(Vector3.BACK, side * _face[3])
	for i in _ears.size():
		var side := 1.0 if i == 0 else -1.0
		# (a flick now and then)
		var flick := sin(_time * 23.0) * 0.25 if fmod(_time + i * 1.7, 6.3) < 0.18 else 0.0
		_ears[i].basis = Basis(Vector3.BACK, -side * (_face[5] + flick)) * Basis(Vector3.RIGHT, _face[4])


## Hanging from a ledge his legs swing under him: a slow idle pendulum, and swung out the way he shimmies, trailing
## behind it and swinging back as he stops (the user: "he should swing his legs when hanging and shimmying").
func _pose_hang_swing(delta: float) -> void:
	_leg_swing_speed += (-_leg_swing * 30.0 - _leg_swing_speed * 2.6 - _shimmy * 9.0) * delta
	_leg_swing += _leg_swing_speed * delta
	var idle := sin(_time * 2.3) * 0.05
	var w := smoothstep(0.3, 1.0, _hang)
	for i in 2:
		var side := 1.0 if i == 0 else -1.0
		var foot := _feet[i].position
		# (about the hip: sideways with the shimmy, back and forth a little, the trailing leg further)
		var out := Vector3(clampf(_leg_swing * 0.22 + _shimmy * side * 0.04, -0.3, 0.3), absf(_leg_swing) * 0.08, idle + sin(_time * 3.1 + side) * 0.03 * absf(_shimmy))
		_solve_leg(i, side, foot + out * w, _feet[i].basis)


## Climbing (Scurry): his all-fours pose turned up onto the surface ahead of him, belly to it, head up, paws
## gripping it: the whole of him turned about his hips, which the Scurry keeps at a hand's reach from it.
func _pose_climb(w: float) -> void:
	var pivot := Vector3(0.0, _hips.position.y, 0.0)
	var turn := Basis(Vector3.RIGHT, -PI * 0.5 * w)
	_hips.position = pivot + turn * (_hips.position - pivot)
	_hips.basis = turn * _hips.basis


## Now and then, standing about, he lifts his nose and sniffs the air: quick little lifts of the snout, the
## whiskers twitching (the user: "he needs to look at things, and should also sniff the air occasionally").
func _sniffing(delta: float, speed: float) -> void:
	var idle := speed < 0.2 and _air < 0.1 and _quad < 0.3 and _spin_w < 0.05 and _sit_at <= 0.0
	_sniff_wait -= delta if idle else 0.0
	if _sniff_wait <= 0.0 and idle and _sniff_at >= 1.0:
		_sniff_at = 0.0
		_sniff_wait = randf_range(5.0, 11.0)
	if _sniff_at < 1.0:
		_sniff_at = minf(_sniff_at + delta / 1.8, 1.0)
	_sniff = _approach(_sniff, (1.0 if _sniff_at < 1.0 and idle else 0.0), 8.0, delta)
	if _sniff > 0.01:
		# (up and a little to one side, the nose working in quick lifts)
		var twitch := maxf(sin(_sniff_at * TAU * 7.0), 0.0) * 0.07
		_head.basis = _slerp(_head.basis, Basis(Vector3.UP, sin(_sniff_at * PI) * 0.35) * Basis(Vector3.RIGHT, -0.38 - twitch), _sniff)


## His fur and whiskers spring: each region of him (FUR_REGIONS, the regions the model's spikes are tagged with)
## has a lag that is thrown back by how its part of him moves and springs back, and the fur shader bends that
## region's spikes by it, flex squared (after Gloaming's LockHair and its springing tips; the user: "his hair fur
## spikes should react to physics", "his whiskers should also be physics springs").
func _spring_fur(delta: float) -> void:
	if _fur_materials.is_empty() or delta <= 0.0:
		return
	var parts := _fur_parts()
	var mesh_basis := _fur_mesh.global_basis.orthonormalized().inverse()
	for r in parts.size():
		var here: Vector3 = parts[r].global_position if parts[r] else global_position
		if _fur_seen[r] == Vector3.INF:
			_fur_seen[r] = here
			_fur_speed_was[r] = Vector3.ZERO
		var speed := (here - _fur_seen[r]) / delta
		var accel := (speed - _fur_speed_was[r]) / delta
		_fur_seen[r] = here
		_fur_speed_was[r] = speed
		# (a spring on each: thrown back against how it is hurried, and the whiskers flicking as he sniffs)
		var push := -accel.limit_length(60.0) * 1.3 + Vector3.DOWN * 1.2
		if r == FUR_HEAD:
			push += Vector3(sin(_time * 41.0), sin(_time * 37.0), 0.0) * 18.0 * _sniff
		_fur_lag_speed[r] += (push - _fur_lag[r] * FUR_STIFFNESS - _fur_lag_speed[r] * FUR_DAMPING) * delta
		_fur_lag[r] = (_fur_lag[r] + _fur_lag_speed[r] * delta).limit_length(0.12)
		_fur_uniform[r] = mesh_basis * _fur_lag[r]
	for material in _fur_materials:
		material.set_shader_parameter(&"lags", _fur_uniform)


## The joint each fur region follows, in the order the model's tags count them (tools/build_raccoon.py REGION).
func _fur_parts() -> Array[Node3D]:
	var parts: Array[Node3D] = [_hips, _chest if _chest else _spine, _shoulders[0], _elbows[0], _shoulders[1], _elbows[1],
		_thighs[0], _shins[0], _thighs[1], _shins[1]]
	for k in TAIL_BONES:
		parts.append(_tail[k] if k < _tail.size() else null)
	parts.append(_head)
	return parts


## Every surface of the model shaded as Toon shades it, and with the springing fur (a vertex stage added to Toon's
## shader: only points tagged as spikes move).
func _make_fur() -> void:
	var meshes := _figure.find_children("*", "MeshInstance3D", true, false)
	if meshes.is_empty():
		return
	_fur_mesh = meshes[0]
	var shader := Shader.new()
	shader.code = Toon.SHADER.replace("void fragment() {", FUR_VERTEX + "\nvoid fragment() {").replace(
			"ALBEDO = albedo * (1.0 - stripe * line);",
			"ALBEDO = albedo * (1.0 - stripe * line) * mix(vec3(1.0), COLOR.rgb * GRIT_SCALE, COLOR.a);")
	for part: MeshInstance3D in meshes:
		for surface in part.mesh.get_surface_count():
			var toon := part.get_surface_override_material(surface) as ShaderMaterial
			if toon == null:
				continue
			var fur := ShaderMaterial.new()
			fur.shader = shader
			for uniform: Dictionary in toon.shader.get_shader_uniform_list():
				fur.set_shader_parameter(uniform["name"], toon.get_shader_parameter(uniform["name"]))
			part.set_surface_override_material(surface, fur)
			_fur_materials.append(fur)
	var regions := _fur_parts().size()
	_fur_lag.resize(regions)
	_fur_lag_speed.resize(regions)
	_fur_seen.resize(regions)
	_fur_speed_was.resize(regions)
	_fur_uniform.resize(regions)
	_fur_seen.fill(Vector3.INF)


func restyle() -> void:
	super()
	if is_node_ready() or not _tail.is_empty():
		_fur_materials.clear()
		_make_fur()


## Swept round in the spin, the tip of his tail leaves an arc of little puffs behind it, so the eye follows the tail.
func _swoosh(spin: float) -> void:
	if _swoosh_puffs == null:
		_swoosh_puffs = CPUParticles3D.new()
		_swoosh_puffs.top_level = true
		_swoosh_puffs.amount = 40
		_swoosh_puffs.lifetime = 0.3
		_swoosh_puffs.local_coords = false
		_swoosh_puffs.direction = Vector3.UP
		_swoosh_puffs.spread = 180.0
		_swoosh_puffs.initial_velocity_min = 0.1
		_swoosh_puffs.initial_velocity_max = 0.4
		_swoosh_puffs.gravity = Vector3.ZERO
		var curve := Curve.new()
		curve.add_point(Vector2(0.0, 1.0))
		curve.add_point(Vector2(1.0, 0.0))
		_swoosh_puffs.scale_amount_curve = curve
		var puff := SphereMesh.new()
		puff.radius = 0.05
		puff.height = 0.1
		puff.radial_segments = 8
		puff.rings = 4
		var look := StandardMaterial3D.new()
		look.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		look.albedo_color = Color(1.0, 0.98, 0.92, 0.75)
		look.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		puff.material = look
		_swoosh_puffs.mesh = puff
		add_child(_swoosh_puffs)
	var sweeping := (spin > SPIN_WIND and spin < SPIN_TURNED) or _glide > 0.5
	_swoosh_puffs.emitting = sweeping
	if _points.size() > TAIL_BONES:
		_swoosh_puffs.global_position = _points[TAIL_BONES]


## The rotor's look: a pale blur of a disc where his tail whirls, and puffs of air thrown off it.
func _rotor(delta: float) -> void:
	if _rotor_disc == null:
		_rotor_disc = MeshInstance3D.new()
		var disc := CylinderMesh.new()
		disc.top_radius = 0.42
		disc.bottom_radius = 0.42
		disc.height = 0.02
		disc.radial_segments = 24
		_rotor_disc.mesh = disc
		var blur := StandardMaterial3D.new()
		blur.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		blur.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		blur.albedo_color = Color(1.0, 0.97, 0.9, 0.22)
		blur.cull_mode = BaseMaterial3D.CULL_DISABLED
		_rotor_disc.material_override = blur
		_rotor_disc.top_level = true
		add_child(_rotor_disc)
		_rotor_puffs = CPUParticles3D.new()
		_rotor_puffs.top_level = true
		_rotor_puffs.amount = 24
		_rotor_puffs.lifetime = 0.45
		_rotor_puffs.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
		_rotor_puffs.emission_ring_axis = Vector3.UP
		_rotor_puffs.emission_ring_radius = 0.42
		_rotor_puffs.emission_ring_inner_radius = 0.38
		_rotor_puffs.emission_ring_height = 0.02
		_rotor_puffs.direction = Vector3.DOWN
		_rotor_puffs.spread = 25.0
		_rotor_puffs.initial_velocity_min = 1.2
		_rotor_puffs.initial_velocity_max = 2.0
		_rotor_puffs.gravity = Vector3.ZERO
		_rotor_puffs.scale_amount_min = 0.5
		_rotor_puffs.scale_amount_max = 1.0
		var curve := Curve.new()
		curve.add_point(Vector2(0.0, 0.4))
		curve.add_point(Vector2(0.3, 1.0))
		curve.add_point(Vector2(1.0, 0.0))
		_rotor_puffs.scale_amount_curve = curve
		var puff := SphereMesh.new()
		puff.radius = 0.06
		puff.height = 0.12
		puff.radial_segments = 8
		puff.rings = 4
		var puff_material := StandardMaterial3D.new()
		puff_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		puff_material.albedo_color = Color(1.0, 1.0, 1.0, 0.7)
		puff_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		puff.material = puff_material
		_rotor_puffs.mesh = puff
		add_child(_rotor_puffs)
	var on := _glide > 0.3
	_rotor_disc.visible = on
	_rotor_puffs.emitting = on
	if on and _points.size() > TAIL_BONES:
		# (centred over the whirling end of his tail, turning with it)
		var middle := (_points[ROTOR_FROM] + _points[TAIL_BONES]) * 0.5
		var hub := _points[ROTOR_FROM].lerp(Vector3(_points[ROTOR_FROM].x, middle.y, _points[ROTOR_FROM].z), 1.0)
		_rotor_disc.global_transform = Transform3D(Basis(Vector3.UP, _twirl), hub)
		(_rotor_disc.material_override as StandardMaterial3D).albedo_color.a = 0.22 * _glide
		_rotor_puffs.global_position = hub


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
		# (eased in and out: round at a pace the eye can follow; the user, 2026-11-01: "he spins way too fast")
		yaw = -SPIN_BACK + (TAU + SPIN_BACK) * smoothstep(0.0, 1.0, s)
	_spin_trail = clampf((yaw - _spin_yaw) / maxf(get_process_delta_time(), 0.001) * 0.045, -0.2, 1.3) if at < SPIN_TURNED else _spin_trail * 0.85
	_spin_yaw = yaw
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
	# (a raccoon's run, 2026-11-01, "higher quality a little bouncier and more raccoonie": a bouncy lope, the rump
	# thrown high, a humped back, a rolling waddle, hind feet reaching up by the fore paws)
	var flight := _bump(_qphase, 0.2, 0.62) * 0.21 + _bump(fposmod(_qphase - 0.7, 1.0), 0.0, 0.34) * 0.08
	var hips_y := _hip_height * lerpf(0.72, 0.77, _gallop) + sin(2.0 * cycle) * 0.01 * moving * (1.0 - _gallop) + flight * bounding
	# (rump up, shoulders down, as a raccoon goes: his arms are short)
	# (bounding, his back stretches out flat in the air and rounds as his hind feet come up under him)
	var lean := lerpf(1.82, 1.8, _gallop) + cos(TAU * (_qphase - 0.9)) * 0.3 * bounding
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
	# (the waddle: his rump rolls and swings from side to side with each bound, more at a walk's amble)
	var waddle := sin(cycle) * moving * lerpf(0.16, 0.1, _gallop)
	_hips.basis = _slerp(_hips.basis, Basis(Vector3.UP, waddle * 0.6) * Basis(Vector3.BACK, waddle) * Basis(Vector3.RIGHT, lean * 0.48), w)
	_spine.basis = _slerp(_spine.basis, Basis(Vector3.RIGHT, lean * 0.33), w)
	if _chest:
		_chest.basis = _slerp(_chest.basis, Basis(Vector3.RIGHT, lean * 0.19), w)
	if _neck:
		_neck.basis = _slerp(_neck.basis, Basis(Vector3.RIGHT, -lean * 0.45), w)
	# (head low and nodding against the bound, steadied against the waddle)
	_head.basis = _slerp(_head.basis, Basis(Vector3.BACK, -waddle * 0.8) * Basis(Vector3.RIGHT, -lean * 0.55 + 0.1 + sin(cycle * 2.0) * 0.05 * moving + sin(cycle + 2.2) * 0.12 * bounding), w)

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
		step.x -= _bump(at, duty - 0.02, 0.5) * 0.16 * bounding
		# (and swung far forward as he gathers, to land up by his fore paws: the paired tracks a raccoon leaves)
		step.x += _bump(at, 0.55, 1.0) * 0.2 * bounding
		var point := Vector3(side * 0.11, ANKLE + step.y, -0.07 + step.x)
		_footfall(i, at, point, w, moving)
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
		var point := Vector3(side * 0.095, 0.03 + step.y, shoulder.z + 0.05 + step.x)
		_footfall(i + 2, at, point, w, moving)
		# (in a leap: reaching out ahead, and down for the ground coming down)
		point = point.lerp(Vector3(side * 0.12, 0.16 - 0.12 * down, shoulder.z + 0.28 - 0.06 * down), _leap_w)
		var pole := (global_basis * Vector3(side * 0.3, 0.0, -1.0)).normalized()
		_solve_arm(i, side, to_global(point) - fingers * 0.03, _forearm, w, pole)
		_lay_hand(i, side, Vector3.UP, fingers, w * (1.0 - 0.6 * clampf(step.y / maxf(lift, 0.001), 0.0, 1.0)))


## 0 outside a..b, rising to 1 halfway between and back down.
static func _bump(x: float, a: float, b: float) -> float:
	return sin(PI * clampf((x - a) / (b - a), 0.0, 1.0))


## Tells of a paw coming down: its cycle has come round past the start (where it is set down).
func _footfall(paw: int, at: float, point: Vector3, w: float, moving: float) -> void:
	if at < _paw_was[paw] - 0.5 and w > 0.6 and moving > 0.5:
		stepped.emit(to_global(Vector3(point.x, 0.0, point.z)))
	_paw_was[paw] = at


## Where a foot is through one cycle: (how far ahead of its middle, how high).
## Down for the first `duty` of it, going back under him; then lifted and brought forward.
static func _cycle(at: float, duty: float, half: float, lift: float) -> Vector2:
	if at < duty:
		return Vector2(half - 2.0 * half * at / duty, 0.0)
	var s := (at - duty) / (1.0 - duty)
	return Vector2(-half + 2.0 * half * (0.5 - 0.5 * cos(PI * s)), sin(PI * s) * lift)


## Twirling his tail over his head to come down slowly: arms out, legs hanging.
func _pose_glide(w: float) -> void:
	# Hanging by his rump under his whirling tail (the user: "his helicopter tail needs to spin from the base of his
	# tail ... he should be pinned by his butt"): the whole of him turned about the root of his tail, so that his
	# rump is the top of him and the rest hangs below it, swaying, arms and legs dangling.
	var pivot := _hips.transform * _tail[0].position if not _tail.is_empty() else _hips.position
	var sway := sin(_time * 4.2) * 0.08
	var hang := Basis(Vector3.RIGHT, (1.15 + sway) * w) * Basis(Vector3.BACK, sin(_time * 3.1) * 0.08 * w)
	_hips.transform = Transform3D(hang, pivot) * Transform3D(Basis.IDENTITY, -pivot) * _hips.transform
	var hips_inverse := _hips.transform.affine_inverse()
	for i in 2:
		var side := 1.0 if i == 0 else -1.0
		var shoulder := to_local(_shoulders[i].global_position)
		_solve_arm(i, side, to_global(shoulder + Vector3(side * 0.06, -0.34, 0.05 + sin(_time * 5.0 + side) * 0.05)), _forearm, w)
		var hip := _hips.transform * Vector3(side * _hip_width, _hip_drop, 0.0)
		var foot := hip + Vector3(side * 0.03, -0.36, sin(_time * 4.2 + side * 1.3) * 0.06)
		_solve_leg(i, side, hips_inverse * foot, _hips.basis.inverse() * Basis(Vector3.RIGHT, 0.7))
	_head.basis = _slerp(_head.basis, Basis(Vector3.RIGHT, -0.9), w)


## The tail's shape for now, in the hips' space, as a direction for each segment.
func _tail_shape(speed: float, spin: float) -> Array[Vector3]:
	var run := clampf(speed / 3.0, 0.0, 1.0)
	var wag := sin(_time * 2.1) * 0.25 * (1.0 - run) + sin(TAU * _phase) * 0.12 * run
	var dirs: Array[Vector3] = []
	for k in TAIL_BONES:
		var down: float = lerpf(lerpf(tail_stand[k], tail_run[k], run), tail_quad[k], _quad)
		# (bobbing with each bound, the tip most)
		down += sin(TAU * _qphase + 1.2 - k * 0.35) * 0.18 * _gallop * _quad * run
		down += sin(_time * 1.3 - k * 0.6) * 0.06 * (1.0 - run)
		var across := wag * (0.4 + 0.15 * k)
		dirs.append(Vector3(sin(across) * cos(down), -sin(down), -cos(across) * cos(down)).normalized())
	if _glide > 0.001:
		# The rotor he hangs from (the user: "spin faster, and he should be hanging from it"): up his back and over
		# his head, leaning back clear of it, and the end of it whirling round flat above him, each segment a
		# little behind the one before.
		# The whole tail is the rotor, whirled round flat from its root (its blade a little swept back, the tip
		# trailing), in his own level space whatever way his hips hang.
		var level := _hips.basis.orthonormalized().inverse()
		for k in TAIL_BONES:
			var angle := _twirl - k * 0.12
			dirs[k] = dirs[k].slerp((level * Vector3(sin(angle), 0.1, cos(angle))).normalized(), _glide)
	if _tj_w > 0.001:
		for k in TAIL_BONES:
			dirs[k] = dirs[k].slerp(Vector3(0.0, 0.05, -1.0), _tj_w)
	if _spin_w > 0.001 and spin < 1.0:
		# Wound round to his left side as he crouches; then, the tail being the attack, held out stiff and straight
		# behind him and swept round with him at his own rate (the user: "the tail should be the focus and it doesnt
		# even spin at the rate he does", "it needs to become stiff when spinning").
		var wound := smoothstep(0.0, SPIN_WIND, spin) * (1.0 - smoothstep(SPIN_WIND, SPIN_WIND + 0.12, spin))
		for k in TAIL_BONES:
			var angle := PI - (1.7 + 0.12 * k) * wound
			dirs[k] = dirs[k].slerp(Vector3(sin(angle), 0.1 + 0.05 * wound, cos(angle)).normalized(), _spin_w)
	return dirs


func _pose_tail(delta: float, speed: float, spin: float) -> void:
	var dirs := _tail_shape(speed, spin)
	# (twirling, it is drawn out long, cartoon-fashion, so its end can whirl over his head)
	var stretch := lerpf(1.0, ROTOR_STRETCH, smoothstep(0.0, 1.0, _glide))
	# (spinning, it is drawn out a little too, and held stiff to its line: below)
	var rigid := _spin_w * smoothstep(SPIN_WIND - 0.05, SPIN_WIND + 0.05, spin) if spin < 1.0 else 0.0
	rigid = maxf(rigid, _tj_w)
	stretch = lerpf(stretch, SPIN_STRETCH, rigid)
	var hips := _hips.global_transform
	var size := global_basis.get_scale().y
	var root := _tail[0].global_position
	var targets := PackedVector3Array([root])
	for k in TAIL_BONES:
		targets.append(targets[k] + (hips.basis.orthonormalized() * dirs[k]) * _tail_len[k] * size * stretch)
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
			_points[k] = _points[k].lerp(targets[k], maxf(0.85 * _glide, 0.95 * rigid))
		# (each segment keeps its length)
		for k in range(1, TAIL_BONES + 1):
			var span := _points[k] - _points[k - 1]
			var length := _tail_len[k - 1] * size * stretch
			_points[k] = _points[k - 1] + (span.normalized() if span.length_squared() > 0.000001 else hips.basis.z * -1.0) * length
	# Each joint turned to lie along its stretch of the chain, and drawn out along itself: the turn worked out from
	# the turns before it (not read back from the joints, which carry their stretch), and the stretch of the one
	# before it taken off again, so each segment is drawn out once and only once.
	var turned := _hips.global_basis.orthonormalized()
	for k in TAIL_BONES:
		var want := turned.inverse() * (_points[k + 1] - _points[k]).normalized()
		var turn := Basis(Quaternion(_tail_dir[k], want.normalized()))
		var undo := Basis.IDENTITY if k == 0 else _along(_tail_dir[k - 1], 1.0 / stretch)
		_tail[k].basis = undo * turn * _along(_tail_dir[k], stretch)
		turned = turned * turn


## A basis that stretches by `by` along `axis` (unit) and leaves the rest as it is.
static func _along(axis: Vector3, by: float) -> Basis:
	var extra := by - 1.0
	return Basis(Vector3.RIGHT + axis * axis.x * extra, Vector3.UP + axis * axis.y * extra, Vector3.BACK + axis * axis.z * extra)


static func _slerp(from: Basis, to: Basis, w: float) -> Basis:
	return Basis(from.orthonormalized().get_rotation_quaternion().slerp(to.orthonormalized().get_rotation_quaternion(), w))
