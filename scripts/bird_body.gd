class_name BirdBody
extends Node3D
## A bird from tools/build_birds.py (models/crow.glb, owl.glb, and redtail.glb for the hawk), posed in code. Its parts
## are a bird's own skeleton, each built at rest with no turn, the wings spread flat: body > head (> the owl's lids), legs, the tail (>
## each tail feather); each wing the humerus (shoulder) > ulna and radius (`_fore`, elbow) > carpometacarpus (`_hand`,
## wrist) > the outer digit (`_digit`), the alula on the wrist. Every flight feather is a part of its own on the bone it
## grows from (tertials, secondaries, primaries, tail feathers), and the covert rows are layers of their own.
## Set what it is doing and it takes it on smoothly:
##
##   var crow := BirdBody.make(&"crow")
##   crow.fold = 1.0          # 0 spread (flying), 1 folded at its sides
##   crow.flap = 1.0          # how hard it beats its wings (0 gliding); `flap_rate` how fast
##   crow.look_at_point(p)    # turns its head (an owl's much further round)
##   crow.peck()  crow.blink()  crow.ruffle()
##   crow.tuck = 1.0          # legs tucked back in flight
##
## The wing is driven as a chain (the user, 2026-11-02: "The bird wings and animations need to be higher quality, with
## rippling feathers and real wing skeleton not just a simple flap animation"): the forearm trails the arm through the
## stroke, the hand the forearm and the digit the hand, so the beat runs out along the wing like a whip; the upstroke
## flexes elbow, wrist and digit and turns the primaries apart. Every feather is then a damped spring of its own (bent
## up or down across it, and twisted about its shaft) pushed by the air it moves through (the speed of its tip across
## the wing's face, the lift of flying) with a flutter running along the trailing edge and out to the tips, more
## gliding. Folded, the feathers settle; a hop, a knock or `wind` ruffles them. The tail fans by what it is doing
## (closed on the ground, open flying, spread wide braking) and twists into turns.

## How each kind beats its wings (after photos: a pied crow's flight composite, crows and a raven in flight,
## Muybridge's plate 762; eagle-owls flying; red-tailed hawks soaring and flapping). Radians unless said: elevation at
## the top and bottom of the stroke and held gliding, the downstroke's share of a beat, how far the hand bows, the
## leading edge turned down driving down and up coming up, the sweep back as it flexes; degrees: elbow and wrist bent
## on the upstroke, primaries fanned wider and each turned about its length, and fanned apart gliding (the fingers);
## "lift": how hard the air of flying bends the feathers' tips up (the soaring hawk's upturned fingers); "tail": how
## wide its tail is fanned in flight (1 as built).
## Crow: rowing, steady beats, the wing bowed down hard, flexed on the upstroke with the primaries parted
## ("fingered"); glides little, wings a shallow V.
const CROW_STROKE := {"up": 0.95, "bottom": -0.62, "glide": 0.1, "down_share": 0.55, "bow": 0.38, "glide_bow": 0.05,
	"pronate": 0.15, "supinate": 0.3, "sweep": 0.35, "elbow": 30.0, "wrist": 52.0, "fan": 12.0, "twist": 28.0,
	"glide_fan": 3.0, "lift": 0.5, "tail": 0.9}
## Owl: deep slow strokes, a high V at the top, the broad wing barely flexed, primaries splayed; long flat glides.
const OWL_STROKE := {"up": 1.15, "bottom": -0.72, "glide": 0.02, "down_share": 0.5, "bow": 0.26, "glide_bow": -0.06,
	"pronate": 0.12, "supinate": 0.4, "sweep": 0.2, "elbow": 18.0, "wrist": 30.0, "fan": 18.0, "twist": 25.0,
	"glide_fan": 4.0, "lift": 0.35, "tail": 1.0}
## Red-tailed hawk: mostly soaring, wings held in a shallow dihedral, the five fingers spread and bent up at the tips,
## the tail fanned; when it beats, slow deep strokes of the broad wing.
const HAWK_STROKE := {"up": 0.9, "bottom": -0.6, "glide": 0.14, "down_share": 0.55, "bow": 0.3, "glide_bow": 0.04,
	"pronate": 0.14, "supinate": 0.32, "sweep": 0.28, "elbow": 22.0, "wrist": 40.0, "fan": 15.0, "twist": 26.0,
	"glide_fan": 9.0, "lift": 1.0, "tail": 1.35}

## Which model each kind is, where its file is not named for it.
const FILES := {&"hawk": "redtail"}

## How far (radians of the stroke) each bone out along the wing lags the one before it, and how much of the difference
## it takes (the whip of the beat).
const CHAIN_LAG := 0.45
const CHAIN_GIVE := 0.45
## The feathers' springs: how quick (radians a second) and how damped (a share of critical), by kind; how far (radians)
## each may bend; how hard the air pushes them (per m/s of their tip across the wing's face); the flutter.
enum Kind { PRIMARY, SECONDARY, TERTIAL, COVERT, TAIL }
const SPRING_RATE := [26.0, 32.0, 34.0, 44.0, 24.0]
const SPRING_DAMP := 0.24
const MOST_BEND := [0.45, 0.3, 0.25, 0.22, 0.3]
const AIR_PUSH := 0.12
const FLUTTER := 0.05
const FLUTTER_RATE := 34.0
## How fast a flying bird is taken to go through the air (m/s, when it is not moved: a test, a hover).
const CRUISE := 9.0
## Past this far from the camera the feathers are not sprung (they lie as the bones put them).
const RIPPLE_REACH := 32.0
## Posed every frame within the first of these (m from the camera), every second frame within the next, and so on;
## out of sight, every OFF_SCREEN_EVERY frames.
const POSE_STEPS: Array[float] = [12.0, 22.0, 35.0]
const OFF_SCREEN_EVERY := 8


class Feather:
	var node: Node3D
	var kind := 0
	var side := 1.0
	var index := 0
	## Its shaft, from its root (its origin), and where its tip is, at rest in its own space.
	var along := Vector3.BACK
	var tip := Vector3.ZERO
	## What it bends up about, and its face's normal, in its own space.
	var axis := Vector3.RIGHT
	var up := Vector3.UP
	## The way it points (radians from straight back, outwards) and how far out along the wing (0 root .. 1 tip).
	var angle := 0.0
	var out := 0.0
	## How much it gives (its stiffness's inverse, more out at the tips).
	var give := 1.0
	var bend := 0.0
	var bend_v := 0.0
	var twist := 0.0
	var twist_v := 0.0
	var last_tip := Vector3.INF
	var base := Basis.IDENTITY


## What it is doing (each eased towards).
var fold := 1.0
var flap := 0.0
## How fast it beats its wings (radians of the stroke a second).
var flap_rate := 17.0
var tuck := 0.0
## Landing: wings thrown forward, body up, legs out (0..1).
var flare := 0.0
var stroke: Dictionary = CROW_STROKE
## Tail fanned up (+) or down (-), radians.
var tail_lift := 0.0
## A breeze through its feathers, folded or not (0..1).
var wind := 0.0
## How far round its head may turn (radians either way).
var neck_reach := 1.4
## How far (radians) the body leans forward, level, flying (it stands more upright); about this point of it.
var flight_lean := 0.3
var body_middle := Vector3(0.0, 0.24, 0.0)

var _parts := {}
var _rest := {}
var _fold := 1.0
var _flap := 0.0
var _phase := 0.0
var _tuck := 0.0
var _flare := 0.0
var _look := Vector3.INF
var _head_yaw := 0.0
var _head_pitch := 0.0
var _peck := 1.0
var _blink := 1.0
var _blink_wait := 2.0
var _time := randf() * 10.0
## How far each folded wing is held out from the shoulder (so it lies on the body, not in it).
var _fold_out := Vector3(0.024, 0.0, 0.0)
## How far over (degrees) the forearm is hinged back on the arm, and the hand out on that, folded (a little short
## of a half turn, so each layer stands a little out from the one under it).
var _hinge := 174.0
## Which way (degrees from straight down, back along the body) the folded primaries lie.
var _primary_lay := 58.0
## Each side's primaries (Feathers, from the wrist out), and every sprung feather.
var _primaries := {}
var _feathers: Array[Feather] = []
var _tail_feathers: Array[Feather] = []
var _last_place := Vector3.INF
var _velocity := Vector3.ZERO
var _last_yaw := INF
var _yaw_rate := 0.0
var _on_screen: VisibleOnScreenNotifier3D
var _skipped := 0
var _skipped_time := 0.0


static func make(kind: StringName) -> BirdBody:
	var body := BirdBody.new()
	body.name = String(kind).capitalize()
	var model: Node3D = (load("res://models/%s.glb" % FILES.get(kind, kind)) as PackedScene).instantiate()
	body.add_child(model)
	Toon.apply(model)
	if kind == &"owl":
		body.neck_reach = 2.6
		body._fold_out = Vector3(0.012, 0.0, -0.01)
		body._primary_lay = 38.0
		body.flap_rate = 10.0
		body.stroke = OWL_STROKE
		body.flight_lean = 1.25
		body.body_middle = Vector3(0.0, 0.28, 0.0)
	elif kind == &"hawk":
		body.neck_reach = 1.6
		body._fold_out = Vector3(0.022, 0.0, -0.004)
		body._primary_lay = 50.0
		body.flap_rate = 11.0
		body.stroke = HAWK_STROKE
		body.flight_lean = 0.5
		body.body_middle = Vector3(0.0, 0.25, 0.0)
	for node: Node in model.find_children("*", "Node3D", true, false):
		var called := String(node.name)
		for joint in ["_body", "_head", "_tail", "_leg_l", "_leg_r", "_lid_l", "_lid_r"]:
			if called.ends_with(joint):
				body._parts[joint] = node
				body._rest[joint] = (node as Node3D).position
		for suffix in ["_wing_l", "_wing_r"]:
			for joint in ["", "_fore", "_hand", "_digit", "_alula"]:
				if called.ends_with(suffix + joint):
					body._parts[suffix + joint] = node
					body._rest[suffix + joint] = (node as Node3D).position
			var side := 1.0 if suffix == "_wing_l" else -1.0
			for kind_name: String in ["_p", "_s", "_tert", "_c"]:
				var at := called.find(suffix + kind_name)
				if at >= 0 and node is MeshInstance3D and called.substr(at + suffix.length() + kind_name.length()).is_valid_int():
					var k := int(called.substr(at + suffix.length() + kind_name.length()))
					var sort: int = {"_p": Kind.PRIMARY, "_s": Kind.SECONDARY, "_tert": Kind.TERTIAL, "_c": Kind.COVERT}[kind_name]
					var feather := body._feather(node as MeshInstance3D, sort, side, k)
					if sort == Kind.PRIMARY:
						var list: Array = body._primaries.get(suffix, [])
						list.append(feather)
						body._primaries[suffix] = list
		var tail_at := called.find("_tail_t")
		if tail_at >= 0 and node is MeshInstance3D:
			body._tail_feathers.append(body._feather(node as MeshInstance3D, Kind.TAIL, 1.0, int(called.substr(tail_at + 7))))
	for suffix in body._primaries:
		(body._primaries[suffix] as Array).sort_custom(func(a: Feather, b: Feather) -> bool: return a.index < b.index)
	# (how far out along the wing each feather is, for the flutter's lag and the tips' give)
	var reach := 0.0
	for f in body._feathers:
		if f.kind != Kind.TAIL:
			reach = maxf(reach, absf(body._in_body(f.node).x))
	for f in body._feathers:
		if f.kind == Kind.TAIL:
			f.out = absf(float(f.index) - (body._tail_feathers.size() - 1) * 0.5) / maxf((body._tail_feathers.size() - 1) * 0.5, 1.0)
		else:
			f.out = clampf(absf(body._in_body(f.node).x) / maxf(reach, 0.01), 0.0, 1.0)
		f.give = lerpf(0.6, 1.3, f.out) if f.kind == Kind.PRIMARY else lerpf(0.8, 1.1, f.out)
	return body


## A feather's spring, read from its mesh (its root at its origin).
func _feather(node: MeshInstance3D, kind: int, side: float, index: int) -> Feather:
	var f := Feather.new()
	f.node = node
	f.kind = kind
	f.side = side
	f.index = index
	var box := node.get_aabb()
	var middle := box.get_center()
	if kind == Kind.COVERT:
		# (a layer of coverts lifts at its trailing edge, about the bone)
		f.tip = middle + Vector3(0.0, 0.0, -box.size.z * 0.5)
		f.along = Vector3.RIGHT
		f.axis = Vector3.RIGHT
		f.up = Vector3.UP
	else:
		f.along = middle.normalized()
		f.tip = f.along * middle.length() * 2.0
		f.up = (Vector3.UP - f.along * f.along.dot(Vector3.UP)).normalized()
		f.axis = f.along.cross(f.up).normalized()
	f.angle = atan2(middle.x * side, -middle.z)
	_feathers.append(f)
	return f


## Where a part is in the bird's own space, at rest (its joints all unturned).
func _in_body(node: Node3D) -> Vector3:
	var at := Vector3.ZERO
	var n: Node = node
	while n is Node3D and n != self:
		at += (n as Node3D).position
		n = n.get_parent()
	return at


## Turns its head towards `point` (INF: straight ahead).
func look_at_point(point: Vector3) -> void:
	_look = point


func peck() -> void:
	if _peck >= 1.0:
		_peck = 0.0


func blink() -> void:
	_blink = 0.0


## Shakes its feathers up (a hop, a knock, shaking itself down): each kicked a little, at random.
func ruffle(amount := 1.0) -> void:
	for f in _feathers:
		f.bend_v += randf_range(-1.0, 1.0) * 6.0 * amount * f.give
		f.twist_v += randf_range(-1.0, 1.0) * 4.0 * amount * f.give


## How many frames to a pose: by how far it is from the camera, and whether any of it is on screen.
func _pose_every() -> int:
	if _on_screen == null:
		_on_screen = VisibleOnScreenNotifier3D.new()
		_on_screen.aabb = AABB(Vector3(-1.0, -0.5, -1.0), Vector3(2.0, 1.6, 2.0))
		add_child(_on_screen)
		return 1
	if not _on_screen.is_on_screen() and DisplayServer.get_name() != "headless":
		return OFF_SCREEN_EVERY
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return 1
	var far := camera.global_position.distance_to(global_position)
	var every := 1
	for step in POSE_STEPS:
		if far > step:
			every += 1
	return every


func _process(delta: float) -> void:
	# (far off or out of sight, posed only every few frames, given all the time since)
	var every := _pose_every()
	_skipped += 1
	_skipped_time += delta
	if _skipped < every:
		return
	delta = _skipped_time
	_skipped = 0
	_skipped_time = 0.0
	_time += delta
	_fold = move_toward(_fold, fold, delta * 3.5)
	_flap = move_toward(_flap, flap, delta * 4.0)
	_tuck = move_toward(_tuck, tuck, delta * 3.0)
	_flare = move_toward(_flare, flare, delta * 3.0)
	_phase = fposmod(_phase + delta * flap_rate * clampf(_flap * 1.5, 0.35, 1.0), TAU)
	_peck = minf(_peck + delta / 0.35, 1.0)
	_blink = minf(_blink + delta / 0.22, 1.0)
	_blink_wait -= delta
	if _blink_wait <= 0.0:
		_blink_wait = randf_range(1.5, 4.5)
		blink()
	# (how fast it goes and turns: what the air does to its feathers and its tail)
	var place := global_position
	if _last_place != Vector3.INF and delta > 0.0:
		var moved := (place - _last_place) / delta
		_velocity = _velocity.lerp(moved if moved.length() < 60.0 else _velocity, 1.0 - exp(-12.0 * delta))
	_last_place = place
	var ahead := global_basis.z
	var yaw := atan2(ahead.x, ahead.z)
	if _last_yaw != INF and delta > 0.0:
		_yaw_rate = lerpf(_yaw_rate, clampf(angle_difference(_last_yaw, yaw) / delta, -6.0, 6.0), 1.0 - exp(-8.0 * delta))
	_last_yaw = yaw
	# The head: towards what it looks at, turned at the neck, pitched; a peck ducks it down and back
	var yaw_head := 0.0
	var tilt := 0.0
	var lean := (flight_lean * (1.0 - _flare) - 0.25 * _flare) * (1.0 - smoothstep(0.0, 1.0, _fold))
	var head := _parts.get("_head") as Node3D
	if head and _look != Vector3.INF:
		var local := global_transform.affine_inverse() * _look - head.position
		yaw_head = clampf(atan2(local.x, local.z), -neck_reach, neck_reach)
		tilt = clampf(-atan2(local.y, Vector2(local.x, local.z).length()), -0.6, 0.6)
	_head_yaw = lerp_angle(_head_yaw, yaw_head, 1.0 - exp(-10.0 * delta))
	_head_pitch = lerpf(_head_pitch, tilt, 1.0 - exp(-10.0 * delta))
	if head:
		var dip := sin(_peck * PI) * 1.1
		head.basis = Basis(Vector3.UP, _head_yaw) * Basis(Vector3.RIGHT, _head_pitch + dip - lean)
		head.position = _rest["_head"] + Vector3(0.0, -0.02, 0.025) * sin(_peck * PI)
	for side_name in ["_lid_l", "_lid_r"]:
		var lid := _parts.get(side_name) as Node3D
		if lid:
			lid.basis = Basis(Vector3.RIGHT, 0.68 * sin(_blink * PI))
	_pose_wings()
	var trunk := _parts.get("_body") as Node3D
	if trunk:
		trunk.basis = Basis(Vector3.RIGHT, lean)
		# (the body lifted on each downstroke, dropping a little as the wings come up)
		var lift := -0.018 * float(_stroke(1.0)[0]) * _flap * (1.0 - smoothstep(0.0, 1.0, _fold))
		trunk.position = body_middle - trunk.basis * body_middle + Vector3.UP * lift
	_pose_tail()
	for side_name in ["_leg_l", "_leg_r"]:
		var leg := _parts.get(side_name) as Node3D
		if leg:
			leg.basis = Basis(Vector3.RIGHT, 1.25 * _tuck * (1.0 - _flare) - 0.7 * _flare)
	_ripple(delta)


## Where the wing is in its stroke at `phase` (0 at the top): [elevation at the shoulder (radians, up +), flex (0..1:
## elbow and wrist bent, the hand swept back, as on the upstroke), bowing of the hand (radians, tips down -),
## pronation (radians, leading edge down +)]. Beating with `amount` of a full stroke; otherwise held to glide.
func _stroke_at(phase: float, amount: float) -> Array:
	var s: Dictionary = stroke
	var p := fposmod(phase, TAU) / TAU
	var down: float = s.down_share
	var elevation: float
	var flex := 0.0
	var bow := 0.0
	var pronate := 0.0
	if p < down:
		# The downstroke: the wing straight out, swept a little forward, driven down; the hand bowed down by the air
		var u := p / down
		elevation = lerpf(s.up, s.bottom, (1.0 - cos(PI * u)) * 0.5)
		bow = -s.bow * sin(PI * u)
		pronate = s.pronate * sin(PI * u)
	else:
		# The upstroke: elbow and wrist bent, the hand swept back and turned so the primaries part, raised again
		var u := (p - down) / (1.0 - down)
		elevation = lerpf(s.bottom, s.up, (1.0 - cos(PI * u)) * 0.5)
		flex = sin(PI * minf(u * 1.15, 1.0))
		bow = s.bow * 0.5 * sin(PI * u)
		pronate = -s.supinate * sin(PI * u)
	return [lerpf(s.glide, elevation, amount), flex * amount, lerpf(s.glide_bow, bow, amount), pronate * amount]


func _stroke(amount: float) -> Array:
	return _stroke_at(_phase, amount)


func _pose_wings() -> void:
	var f := smoothstep(0.0, 1.0, _fold)
	var amount := _flap * (1.0 - f)
	var s: Dictionary = stroke
	var at := _stroke(_flap)
	var elevation: float = at[0]
	var flex: float = at[1]
	var bow: float = at[2]
	var pronate: float = at[3]
	# (the whip: each bone out along the wing where the one before it was a moment ago)
	var trail: Array[float] = []
	for k in 4:
		trail.append(float(_stroke_at(_phase - CHAIN_LAG * k, _flap)[0]))
	var whip_fore := (trail[1] - trail[0]) * CHAIN_GIVE
	var whip_hand := (trail[2] - trail[1]) * CHAIN_GIVE
	var whip_digit := (trail[3] - trail[2]) * CHAIN_GIVE
	# Landing: wings thrown forward and up, braking
	var braking := _flare * (1.0 - f)
	for side in [1.0, -1.0]:
		var suffix := "_wing_l" if side > 0.0 else "_wing_r"
		var shoulder := _parts.get(suffix) as Node3D
		var fore := _parts.get(suffix + "_fore") as Node3D
		var hand := _parts.get(suffix + "_hand") as Node3D
		var digit := _parts.get(suffix + "_digit") as Node3D
		var alula := _parts.get(suffix + "_alula") as Node3D
		if shoulder == null:
			continue
		# Folded: rolled so its trailing edge hangs down, swung back along the body; the forearm hinged back over the
		# arm and the hand out again over that (a Z, as a bird's wing folds: each hinged across the wing, about Z, so
		# its feathers still trail), each layer a little further out; the hand turned so the primaries lie back
		# along the body towards the tail
		# Spread: raised or lowered at the shoulder (about the body's length), swept back a little as it flexes and
		# forward on the downstroke, turned about its own length (leading edge down driving down, up coming up)
		var sweep: float = s.sweep * flex - 0.1 * (1.0 - flex) * amount - 0.55 * braking
		var spread_shoulder := Basis(Vector3.UP, side * sweep) * Basis(Vector3.BACK, side * (elevation + 0.35 * braking)) \
				* Basis(Vector3.RIGHT, pronate - 0.35 * braking)
		# (each fold turned through by its angle, the spread pose easing out under it: a slerp straight from one to the
		# other went the short way round, flipping the hand over, whenever the beat had it bent past the fold's half turn)
		shoulder.basis = Basis(Vector3.UP, side * deg_to_rad(91.0) * f) * Basis(Vector3.RIGHT, deg_to_rad(-100.0) * f) * spread_shoulder.slerp(Basis.IDENTITY, f)
		shoulder.position = _rest[suffix] + Vector3(side * _fold_out.x, _fold_out.y, _fold_out.z) * f
		# (the hinges: a turn not quite a half, so each layer lies a little out from the one under it)
		if fore:
			# (bent at the elbow, the forearm forward, in the wing's plane; trailing the arm through the stroke)
			var spread_fore := Basis(Vector3.UP, -side * deg_to_rad(s.elbow) * flex) * Basis(Vector3.BACK, side * (bow * 0.35 + whip_fore))
			fore.basis = Basis(Vector3.BACK, -side * deg_to_rad(_hinge) * f) * spread_fore.slerp(Basis.IDENTITY, f)
		if hand:
			# (bent at the wrist, the hand swept back; bowed down out of the wing's plane by the air, trailing the forearm;
			# turned about its length on the upstroke so the primaries open)
			var spread_hand := Basis(Vector3.UP, side * deg_to_rad(s.wrist) * flex) * Basis(Vector3.BACK, side * (bow + whip_hand)) \
					* Basis(Vector3.RIGHT, -0.25 * flex)
			hand.basis = Basis(Vector3.BACK, side * deg_to_rad(_hinge) * f) * spread_hand.slerp(Basis.IDENTITY, f)
		if digit:
			# (the wingtip bends back a little more on the upstroke, and lags the hand)
			var spread_digit := Basis(Vector3.UP, side * deg_to_rad(s.wrist) * 0.3 * flex) * Basis(Vector3.BACK, side * (bow * 0.5 + whip_digit))
			digit.basis = spread_digit.slerp(Basis.IDENTITY, f)
		if alula:
			# (raised off the leading edge when slow: braking to land, and a little at the top of the stroke)
			var raise := clampf(braking + 0.35 * flex, 0.0, 1.0) * (1.0 - f)
			alula.basis = Basis(Vector3.UP, -side * 0.5 * raise) * Basis(Vector3.BACK, side * 0.4 * raise)
		# The primaries: fanned wider and each turned about its own length on the upstroke (so the air slips between
		# them: the crow's "fingers"), parted a little gliding; laid back together folded (each turned in the wing's
		# plane from the way it points to nearly the same way back along the body, the outer ones a little higher)
		var feathers: Array = _primaries.get(suffix, [])
		var middle := (feathers.size() - 1) * 0.5
		var gliding := (1.0 - _flap) * (1.0 - f)
		for k in feathers.size():
			var feather: Feather = feathers[k]
			var spread := (deg_to_rad(s.fan) * flex + deg_to_rad(s.glide_fan) * gliding) * (float(k) - middle) / maxf(middle, 1.0)
			var spread_feather := Basis(Vector3.UP, -side * spread) * Basis(feather.along, -side * deg_to_rad(s.twist) * flex)
			# (those on the digit are laid by the hand's fold: the digit folds straight)
			var laid := deg_to_rad(_primary_lay + 3.0 * k) - feather.angle
			feather.base = spread_feather.slerp(Basis(Vector3.UP, -side * laid), f)


## The tail: fanned closed on the ground, open in flight (as wide as the kind spreads it), wide braking and turning;
## twisted into a turn; lifted and bobbing with the beat.
func _pose_tail() -> void:
	var f := smoothstep(0.0, 1.0, _fold)
	var tail := _parts.get("_tail") as Node3D
	if tail:
		var bob := sin(_phase + 1.2) * 0.12 * _flap * (1.0 - _fold)
		var into_turn := clampf(-_yaw_rate * 0.18, -0.45, 0.45) * (1.0 - f)
		tail.basis = Basis(Vector3.RIGHT, -tail_lift - bob + 0.15 * (1.0 - _fold) + 0.35 * _flare) * Basis(Vector3.BACK, into_turn)
	var open: float = lerpf(0.4, float(stroke.tail) + 0.15 * absf(_yaw_rate), 1.0 - f) + 0.8 * _flare
	for feather in _tail_feathers:
		feather.base = Basis(feather.up, -feather.angle * (open - 1.0))


## Every feather a damped spring, bent by the air its tip moves through and the lift of flying, a flutter running
## along the trailing edge and out to the tips; then posed on its bone's pose (`base`).
func _ripple(delta: float) -> void:
	var f := smoothstep(0.0, 1.0, _fold)
	var camera := get_viewport().get_camera_3d() if is_inside_tree() else null
	var sprung := is_visible_in_tree() and delta > 0.0 \
			and (camera == null or camera.global_position.distance_to(global_position) < RIPPLE_REACH)
	if not sprung:
		for feather in _feathers:
			feather.node.basis = feather.base
			feather.last_tip = Vector3.INF
			feather.bend = 0.0
			feather.bend_v = 0.0
			feather.twist = 0.0
			feather.twist_v = 0.0
		return
	var flying := 1.0 - f
	var air := maxf(_velocity.length(), CRUISE * flying)
	var lift: float = stroke.lift
	var step := minf(delta, 1.0 / 30.0)
	for feather in _feathers:
		var parent := feather.node.get_parent() as Node3D
		var frame := parent.global_transform
		var tip := frame * (feather.node.position + feather.base * feather.tip)
		var moving := Vector3.ZERO
		if feather.last_tip != Vector3.INF:
			moving = (tip - feather.last_tip) / delta
			if moving.length() > 40.0:
				moving = Vector3.ZERO
		feather.last_tip = tip
		var face := (frame.basis * (feather.base * feather.up)).normalized()
		# (pushed back against the way it moves across the wing's face, held up by the air of flying)
		var load := -moving.dot(face) * AIR_PUSH + lift * 0.18 * flying * minf(air / CRUISE, 1.6)
		if feather.kind == Kind.COVERT:
			load *= 0.4
		# (the flutter: a wave out along the wing and back along the trailing edge, more gliding and in a breeze)
		var shimmer := FLUTTER * (flying * minf(air / CRUISE, 1.5) * (1.0 - 0.6 * _flap) + wind)
		load += shimmer * sin(_time * FLUTTER_RATE - feather.out * 5.0 - feather.index * 0.7)
		var most: float = MOST_BEND[feather.kind] * (1.0 - 0.8 * f)
		var want := clampf(load * feather.give, -most, most)
		var rate: float = SPRING_RATE[feather.kind]
		feather.bend_v += (rate * rate * (want - feather.bend) - 2.0 * SPRING_DAMP * rate * feather.bend_v) * step
		feather.bend = clampf(feather.bend + feather.bend_v * step, -most * 1.3, most * 1.3)
		# (a flight feather twists under load as it bends: its trailing vane gives more than its leading one)
		var twist_want := want * 0.5 * feather.side if feather.kind == Kind.PRIMARY or feather.kind == Kind.SECONDARY else 0.0
		feather.twist_v += (rate * rate * (twist_want - feather.twist) - 2.0 * SPRING_DAMP * rate * feather.twist_v) * step
		feather.twist = clampf(feather.twist + feather.twist_v * step, -0.4, 0.4)
		feather.node.basis = feather.base * Basis(feather.axis, feather.bend) * Basis(feather.along, feather.twist)
