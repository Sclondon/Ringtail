class_name Wire
extends Node3D
## A wire strung between two points that the raccoon lands on, walks along and bounces
## on, as in Mario Sunshine (the user, 2026-11-01: "the hemlock tower wires to walk across
## and bounce on"). After Hemlock's Tower's tightrope wires (TowerChunk.wire_point,
## _tick_wire; Player._try_wire, _ride_wire): the wire sags, and is pushed down where he
## is on it by a spring; landing harder pushes it further, and a jump taken at the bottom
## of a bounce goes higher.
##
## Under him rides a small invisible floor that follows the wire, so the Player walks and
## jumps on it as on any ground. He is kept on the line, and steps off at either end.

## The two ends, in the world.
@export var from := Vector3.ZERO
@export var to := Vector3(6.0, 0.0, 0.0)
## How far the middle hangs below a straight line, standing empty.
@export var sag := 0.3
## How far it gives under him standing still.
@export var weight_dip := 0.16
## Extra jump speed off the wire, and more per metre it is bent down when he jumps.
@export var launch := 1.5
@export var dip_boost := 9.0
@export var colour := Color(0.12, 0.11, 0.12)

const SPRING := 70.0
const DAMP := 5.0
const CATCH := 0.42  # how near (sideways) he has to come down to it to land on it
const SEGMENTS := 24

var rider: Player
var riding := false
var t := 0.5
var dip := 0.0
var dip_v := 0.0

var _mesh := ImmediateMesh.new()
var _floor: AnimatableBody3D
var _shape: CollisionShape3D
var _was_y := 0.0
var _boost := false
var _material: StandardMaterial3D


func _ready() -> void:
	# (before the Player moves, so he moves with the floor where it is this frame)
	process_physics_priority = -10
	var drawn := MeshInstance3D.new()
	drawn.mesh = _mesh
	drawn.top_level = true
	drawn.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_material = StandardMaterial3D.new()
	_material.albedo_color = colour
	_material.roughness = 0.6
	add_child(drawn)
	_floor = AnimatableBody3D.new()
	_floor.top_level = true
	_floor.sync_to_physics = false
	_shape = CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.36, 0.1, 0.7)
	_shape.shape = box
	_shape.position.y = -0.05
	_shape.disabled = true
	_floor.add_child(_shape)
	add_child(_floor)
	_draw()
	if rider:
		_was_y = rider.global_position.y
		rider.jumped.connect(func() -> void: _boost = riding)


## Where the wire is at `at` (0 at `from`, 1 at `to`): its sag, and its dip round where he is.
func point(at: float) -> Vector3:
	var p := from.lerp(to, at)
	var where := clampf(t, 0.05, 0.95)
	var shape := at / where if at < where else (1.0 - at) / (1.0 - where)
	p.y -= sag * 4.0 * at * (1.0 - at) + dip * shape
	return p


## How far along it the point nearest `at` is (looking down from above), 0..1.
func along(at: Vector3) -> float:
	var flat := Vector2(to.x - from.x, to.z - from.z)
	var rel := Vector2(at.x - from.x, at.z - from.z)
	return clampf(rel.dot(flat) / maxf(flat.length_squared(), 0.0001), 0.0, 1.0)


func _physics_process(delta: float) -> void:
	if rider == null:
		return
	var here := rider.global_position
	var at := along(here)
	var on_line := point(at)
	var aside := Vector2(here.x - on_line.x, here.z - on_line.z)
	var falling := rider.velocity.y
	if not riding:
		# Coming down onto it: from above it last frame to at or below it now, close enough sideways
		if falling <= 0.0 and _was_y >= on_line.y - 0.05 and here.y <= on_line.y + 0.05 and _was_y - here.y < 1.0 and aside.length() < CATCH and at > 0.02 and at < 0.98 \
				and rider.state == Player.State.FREE:
			riding = true
			t = at
			dip_v += absf(falling) * 0.35
			rider.global_position = Vector3(on_line.x, on_line.y, on_line.z)
	elif at <= 0.015 or at >= 0.985 or here.y > on_line.y + 1.2 or here.y < on_line.y - 0.6 or rider.state != Player.State.FREE:
		riding = false
	if riding:
		t = at
		# (kept on the line: the wire is too thin to stand anywhere but on it)
		rider.global_position.x = on_line.x
		rider.global_position.z = on_line.z
	if _boost:
		_boost = false
		if rider.velocity.y > 0.0:
			# Timed at the bottom of a bounce, it throws him high
			rider.velocity.y += launch + maxf(dip, 0.0) * dip_boost
			dip_v -= 3.0
			riding = false
	# The spring, round a little dip while he stands on it
	var rest := weight_dip if riding and rider.is_on_floor() else 0.0
	dip_v += (-SPRING * (dip - rest) - DAMP * dip_v) * delta
	dip += dip_v * delta
	_place_floor()
	_was_y = rider.global_position.y
	_draw()


func _place_floor() -> void:
	_shape.disabled = not riding
	if not riding:
		return
	var p := point(t)
	var ahead := (point(minf(t + 0.02, 1.0)) - point(maxf(t - 0.02, 0.0))).normalized()
	var flat := Vector3(ahead.x, 0.0, ahead.z).normalized()
	var side := flat.cross(Vector3.UP).normalized()
	var up := side.cross(ahead).normalized() * -1.0 if side.cross(ahead).y < 0.0 else side.cross(ahead).normalized()
	_floor.global_transform = Transform3D(Basis(side, up, ahead).orthonormalized(), p)


func _draw() -> void:
	_mesh.clear_surfaces()
	_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, _material)
	var radius := 0.03
	var sides := 5
	var rings: Array[PackedVector3Array] = []
	for k in SEGMENTS + 1:
		var a := float(k) / SEGMENTS
		var p := point(a)
		var ahead := (point(minf(a + 0.02, 1.0)) - point(maxf(a - 0.02, 0.0))).normalized()
		var u := ahead.cross(Vector3.UP).normalized()
		var v := u.cross(ahead).normalized()
		var ring := PackedVector3Array()
		for s in sides:
			var angle := TAU * s / sides
			ring.append(p + (u * cos(angle) + v * sin(angle)) * radius)
		rings.append(ring)
	for k in SEGMENTS:
		for s in sides:
			var s1 := (s + 1) % sides
			var normal := (rings[k][s] + rings[k][s1] - point(float(k) / SEGMENTS) * 2.0).normalized()
			_mesh.surface_set_normal(normal)
			_mesh.surface_add_vertex(rings[k][s])
			_mesh.surface_add_vertex(rings[k + 1][s])
			_mesh.surface_add_vertex(rings[k + 1][s1])
			_mesh.surface_add_vertex(rings[k][s])
			_mesh.surface_add_vertex(rings[k + 1][s1])
			_mesh.surface_add_vertex(rings[k][s1])
	_mesh.surface_end()
