class_name BirdBody
extends Node3D
## A bird from tools/build_birds.py (models/crow.glb, owl.glb), posed in code: its parts are a tree of joints (body >
## head, tail, legs; shoulder > elbow > wrist each side; the owl's lids), each built at rest with no turn, the wings
## spread flat. Set what it is doing and it takes it on smoothly:
##
##   var crow := BirdBody.make(&"crow")
##   crow.fold = 1.0          # 0 spread (flying), 1 folded at its sides
##   crow.flap = 1.0          # how hard it beats its wings (0 gliding); `flap_rate` how fast
##   crow.look_at_point(p)    # turns its head (an owl's much further round)
##   crow.peck()  crow.blink()
##   crow.tuck = 1.0          # legs tucked back in flight

## How each kind beats its wings (after photos: a pied crow's flight composite, crows and a raven in flight,
## Muybridge's plate 762; eagle-owls flying). Radians unless said: elevation at the top and bottom of the stroke and
## held gliding, the downstroke's share of a beat, how far the hand bows, the leading edge turned down driving down
## and up coming up, the sweep back as it flexes; degrees: elbow and wrist bent on the upstroke, primaries fanned
## wider and each turned about its length.
## Crow: rowing, steady beats, the wing bowed down hard, flexed on the upstroke with the primaries parted
## ("fingered"); glides little, wings a shallow V.
const CROW_STROKE := {"up": 0.95, "bottom": -0.62, "glide": 0.1, "down_share": 0.55, "bow": 0.38, "glide_bow": 0.05,
	"pronate": 0.15, "supinate": 0.3, "sweep": 0.35, "elbow": 30.0, "wrist": 52.0, "fan": 12.0, "twist": 28.0}
## Owl: deep slow strokes, a high V at the top, the broad wing barely flexed, primaries splayed; long flat glides.
const OWL_STROKE := {"up": 1.15, "bottom": -0.72, "glide": 0.02, "down_share": 0.5, "bow": 0.26, "glide_bow": -0.06,
	"pronate": 0.12, "supinate": 0.4, "sweep": 0.2, "elbow": 18.0, "wrist": 30.0, "fan": 18.0, "twist": 25.0}

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
## How far out each folded wing is held from the shoulder (so it lies on the body, not in it).
var _fold_out := Vector3(0.024, 0.0, 0.0)
## How far over (degrees) the forearm is hinged back on the arm, and the hand out on that, folded (a little short
## of a half turn, so each layer stands a little out from the one under it).
var _hinge := 174.0
## Which way (degrees from straight down, back along the body) the folded primaries lie.
var _primary_lay := 58.0
## Each side's primaries: [node, the way it points spread (radians from straight back off the wing, outwards)].
var _primaries := {}


static func make(kind: StringName) -> BirdBody:
	var body := BirdBody.new()
	body.name = String(kind).capitalize()
	var model: Node3D = (load("res://models/%s.glb" % kind) as PackedScene).instantiate()
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
	for node: Node in model.find_children("*", "Node3D", true, false):
		var called := String(node.name)
		for joint in ["_body", "_head", "_tail", "_leg_l", "_leg_r", "_wing_l", "_wing_r", "_wing_l_fore", "_wing_r_fore",
				"_wing_l_hand", "_wing_r_hand", "_lid_l", "_lid_r"]:
			if called.ends_with(joint):
				body._parts[joint] = node
				body._rest[joint] = (node as Node3D).position
		for suffix in ["_wing_l", "_wing_r"]:
			var at := called.find(suffix + "_p")
			if at >= 0 and node is MeshInstance3D:
				# (the way it points: from its root, its origin, to the middle of it)
				var middle := (node as MeshInstance3D).get_aabb().get_center()
				var side := 1.0 if suffix == "_wing_l" else -1.0
				var list: Array = body._primaries.get(suffix, [])
				list.append([node, atan2(middle.x * side, -middle.z), int(called.substr(at + suffix.length() + 2)), middle.normalized()])
				body._primaries[suffix] = list
	for suffix in body._primaries:
		(body._primaries[suffix] as Array).sort_custom(func(a: Array, b: Array) -> bool: return a[2] < b[2])
	return body


## Turns its head towards `point` (INF: straight ahead).
func look_at_point(point: Vector3) -> void:
	_look = point


func peck() -> void:
	if _peck >= 1.0:
		_peck = 0.0


func blink() -> void:
	_blink = 0.0


func _process(delta: float) -> void:
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
	# The head: towards what it looks at, turned at the neck, pitched; a peck ducks it down and back
	var yaw := 0.0
	var tilt := 0.0
	var lean := (flight_lean * (1.0 - _flare) - 0.25 * _flare) * (1.0 - smoothstep(0.0, 1.0, _fold))
	var head := _parts.get("_head") as Node3D
	if head and _look != Vector3.INF:
		var local := global_transform.affine_inverse() * _look - head.position
		yaw = clampf(atan2(local.x, local.z), -neck_reach, neck_reach)
		tilt = clampf(-atan2(local.y, Vector2(local.x, local.z).length()), -0.6, 0.6)
	_head_yaw = lerp_angle(_head_yaw, yaw, 1.0 - exp(-10.0 * delta))
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
	var tail := _parts.get("_tail") as Node3D
	if tail:
		# (it bobs with each beat, and fans level in flight)
		var bob := sin(_phase + 1.2) * 0.12 * _flap * (1.0 - _fold)
		tail.basis = Basis(Vector3.RIGHT, -tail_lift - bob + 0.15 * (1.0 - _fold))
	for side_name in ["_leg_l", "_leg_r"]:
		var leg := _parts.get(side_name) as Node3D
		if leg:
			leg.basis = Basis(Vector3.RIGHT, 1.25 * _tuck * (1.0 - _flare) - 0.7 * _flare)


## Where the wing is in its stroke, from `_phase` (0 at the top): [elevation at the shoulder (radians, up +),
## flex (0..1: elbow and wrist bent, the hand swept back, as on the upstroke), bowing of the hand (radians, tips down
## -), pronation (radians, leading edge down +)]. Beating with `amount` of a full stroke; otherwise held to glide.
func _stroke(amount: float) -> Array:
	var s: Dictionary = stroke
	var p := _phase / TAU
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


func _pose_wings() -> void:
	var f := smoothstep(0.0, 1.0, _fold)
	var amount := _flap * (1.0 - f)
	var s: Dictionary = stroke
	var at := _stroke(_flap)
	var elevation: float = at[0]
	var flex: float = at[1]
	var bow: float = at[2]
	var pronate: float = at[3]
	# Landing: wings thrown forward and up, braking
	var braking := _flare * (1.0 - f)
	for side in [1.0, -1.0]:
		var suffix := "_wing_l" if side > 0.0 else "_wing_r"
		var shoulder := _parts.get(suffix) as Node3D
		var fore := _parts.get(suffix + "_fore") as Node3D
		var hand := _parts.get(suffix + "_hand") as Node3D
		if shoulder == null:
			continue
		# Folded: rolled so its trailing edge hangs down, swung back along the body; the forearm hinged back over the
		# arm and the hand out again over that (a Z, as a bird's wing folds: each hinged across the wing, about Z, so
		# its feathers still trail), each layer a little further out; the hand turned so the primaries lie back
		# along the body towards the tail
		var folded_shoulder := Basis(Vector3.UP, side * deg_to_rad(91.0)) * Basis(Vector3.RIGHT, deg_to_rad(-100.0))
		# Spread: raised or lowered at the shoulder (about the body's length), swept back a little as it flexes and
		# forward on the downstroke, turned about its own length (leading edge down driving down, up coming up)
		var sweep: float = s.sweep * flex - 0.1 * (1.0 - flex) * amount - 0.55 * braking
		var spread_shoulder := Basis(Vector3.UP, side * sweep) * Basis(Vector3.BACK, side * (elevation + 0.35 * braking)) \
				* Basis(Vector3.RIGHT, pronate - 0.35 * braking)
		shoulder.basis = spread_shoulder.slerp(folded_shoulder, f)
		shoulder.position = _rest[suffix] + Vector3(side * _fold_out.x, _fold_out.y, _fold_out.z) * f
		# (the hinges, eased in through a turn that is not quite a half, so the slerp goes the outward way round)
		if fore:
			# (bent at the elbow, the forearm forward, in the wing's plane; and it trails the shoulder a little)
			var spread_fore := Basis(Vector3.UP, -side * deg_to_rad(s.elbow) * flex) * Basis(Vector3.BACK, side * bow * 0.35)
			fore.basis = spread_fore.slerp(Basis(Vector3.BACK, -side * deg_to_rad(_hinge)), f)
		if hand:
			# (bent at the wrist, the hand swept back; bowed down out of the wing's plane by the air)
			var spread_hand := Basis(Vector3.UP, side * deg_to_rad(s.wrist) * flex) * Basis(Vector3.BACK, side * bow)
			hand.basis = spread_hand.slerp(Basis(Vector3.BACK, side * deg_to_rad(_hinge)), f)
		# The primaries: fanned wider and each turned about its own length on the upstroke (so the air slips between
		# them: the crow's "fingers"); laid back together folded (each turned in the wing's plane from the way it points
		# to nearly the same way back along the body, the outer ones a little higher, over the others)
		var feathers: Array = _primaries.get(suffix, [])
		var middle := (feathers.size() - 1) * 0.5
		for k in feathers.size():
			var feather: Node3D = feathers[k][0]
			var along: Vector3 = feathers[k][3]
			var fan := deg_to_rad(s.fan) * flex * (float(k) - middle) / maxf(middle, 1.0)
			var spread_feather := Basis(Vector3.UP, -side * fan) * Basis(along, -side * deg_to_rad(s.twist) * flex)
			var laid := deg_to_rad(_primary_lay + 3.0 * k) - float(feathers[k][1])
			feather.basis = spread_feather.slerp(Basis(Vector3.UP, -side * laid), f)
