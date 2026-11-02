class_name HazardCar
extends AnimatableBody3D
## A vehicle (models/vehicle_<kind>.glb, tools/build_vehicles.py) driving round a road loop on the left, as in Japan
## (Hazards gives it the lane). Kinds: a hatchback, a taxi, a kei truck, a kei van and a city bus, each its own size and
## pace (the user, 2026-11-02: "the roads should be wider, the cars bigger and faster" / "and there should be different
## types, busses etc"). It slows for corners, keeps back from whatever is ahead of it on the same road, and now and
## then stops a moment as at a junction; a bus stops longer, at its stops. Run into by its front, the raccoon is hurt
## and thrown; he can jump onto its roof and ride. Claude's picks: the kinds, speeds, stops, colours.
##
## On the hill (the user: "need to be scaled to the human models and actually work on the slopes, with more realistic
## wheels and such"): each wheel feels down for the road; the body sits at its wheels' height, pitched and rolled to
## the ground under them; each wheel rides up and down a little on its own; the front wheels steer into the turns, the
## body leans out in them and dips braking. It climbs a little slower and takes a steep downhill bend slower still.
##
## Lights (the user: "need bright headlights at night"): its lamps always glow; at night the nearest few to him
## (`LIT`) throw real beams and red tail light, and every one a soft cone of light ahead. Night is DayNight.current's
## (if there is one); `lights` forces it (-1: follow the day; 0 off; 1 on).

## Each kind: its size (width, height to the roof, length), cruising and cornering speeds (m/s), and the radius of its
## wheels.
const KINDS := {
	&"hatchback": {"size": Vector3(1.7, 1.48, 4.05), "cruise": 20.0, "corner": 7.0, "wheel": 0.33},
	&"taxi": {"size": Vector3(1.7, 1.45, 4.65), "cruise": 21.0, "corner": 7.0, "wheel": 0.33},
	&"kei_truck": {"size": Vector3(1.48, 1.8, 3.42), "cruise": 17.0, "corner": 6.0, "wheel": 0.29},
	&"kei_van": {"size": Vector3(1.48, 1.88, 3.42), "cruise": 17.0, "corner": 6.0, "wheel": 0.29},
	&"bus": {"size": Vector3(2.5, 3.05, 10.55), "cruise": 13.0, "corner": 4.5, "wheel": 0.48},
}
## Room kept to whatever is ahead on the road (m).
const GAP := 3.0
## How hard it speeds up and brakes (m/s²): hard, so it is on him quickly out of a bend (the user, 2026-11-02: "the
## cars need to be way faster like hard to dodge"). A bus or a kei takes it more gently (KIND_PULL).
const PULL := 7.0
const BRAKE := 14.0
const KIND_PULL := {&"bus": 0.7, &"kei_truck": 0.85, &"kei_van": 0.85}
## How far each wheel may ride up or down on its own (m), and how many cars nearest him throw real light at night.
const TRAVEL := 0.12
const LIT := 3

## Lights forced on or off for every vehicle (-1: by the time of day).
static var lights := -1.0

var kind := &"hatchback"
var route := PackedVector3Array()
## Which road it is on (cars keep back only from those on the same road), and where on the loop it starts, 0..1.
var road := 0
var start := 0.0
var paint := Color(0.85, 0.22, 0.18)
## A second colour (the bus's lower half, the taxi's band): `paint` and this, by material.
var paint2 := Color(0.93, 0.9, 0.8)
var player: Player
var cruise := 11.0
var corner_speed := 4.5
## Half its size (width, height, length): what it fills, for anything that would be run over (Villager, SquadRaccoon).
var half_size := Vector3(0.85, 0.74, 2.0)
## Where along the loop a bus stops (m), if the road has stops (bus_stop_<n> markers near it).
var stops: Array[float] = []
## How far each wheel's contact is from the road under it, last step (m): for tests.
var contact_error := 0.0
## The speed the bend it is in allows, and how sharp that bend is (0..1): for tests.
var bend_speed := INF
var bend_sharp := 0.0

var along := 0.0
var speed := 0.0
var _lengths := PackedFloat32Array()
var _total := 0.0
var _wheels: Array[Node3D] = []
var _wheel_rest: Array[Vector3] = []
var _wheel_front: Array[bool] = []
var _wheel_ride: Array[float] = []
var _wheel_spin := 0.0
var _wheel_radius := 0.33
var _body: Node3D
var _stop_left := 0.0
var _stop_wait := randf_range(10.0, 22.0)
var _hurt_rest := 0.0
var _stopped_at := -1.0
var _pitch := 0.0
var _roll := 0.0
var _height := 0.0
var _yaw_was := 0.0
var _yaw_rate := 0.0
var _speed_was := 0.0
var _lean := Vector2.ZERO
var _settled := false
var _beams: Array[SpotLight3D] = []
var _tail_light: OmniLight3D
var _cones: MeshInstance3D
var _light_look := randf() * 0.5


func _ready() -> void:
	add_to_group(&"hazards")
	add_to_group(&"cars")
	sync_to_physics = true
	collision_layer = 1
	collision_mask = 0
	var spec: Dictionary = KINDS.get(kind, KINDS[&"hatchback"])
	var size: Vector3 = spec["size"]
	half_size = size * 0.5
	cruise = spec["cruise"] * randf_range(0.92, 1.06)
	corner_speed = spec["corner"]
	_wheel_radius = spec["wheel"]
	var model: Node3D = (load("res://models/vehicle_%s.glb" % kind) as PackedScene).instantiate()
	add_child(model)
	Toon.apply(model, {"paint": paint, "paint2": paint2})
	_glow(model)
	for node: Node in model.find_children("*", "Node3D", true, false):
		var named := String(node.name)
		if named.contains("_wheel_"):
			_wheels.append(node)
			_wheel_rest.append((node as Node3D).position)
			_wheel_front.append(named.contains("_wheel_f"))
			_wheel_ride.append(0.0)
		elif named.ends_with("_body"):
			_body = node
	# A body to stand on: one box to its roof (its roof is flat enough), a little off the road so it does not catch
	# the kerbs
	var shape := BoxShape3D.new()
	shape.size = Vector3(size.x, size.y - 0.3, size.z)
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.position = Vector3(0.0, 0.3 + (size.y - 0.3) * 0.5, 0.0)
	add_child(collider)
	_make_lights()
	_measure()
	along = start * _total
	_place(0.0)


func _measure() -> void:
	_lengths.clear()
	_total = 0.0
	var n := route.size()
	for i in n:
		var length := route[i].distance_to(route[(i + 1) % n])
		_lengths.append(length)
		_total += length


## How long its loop is (m).
func loop_length() -> float:
	return _total


## Where on the loop `distance` along it is, and the way it runs there.
func point_at(distance: float) -> Array:
	var d := fposmod(distance, maxf(_total, 0.001))
	var n := route.size()
	for i in n:
		if d <= _lengths[i] or i == n - 1:
			var a := route[i]
			var b := route[(i + 1) % n]
			return [a.lerp(b, clampf(d / maxf(_lengths[i], 0.001), 0.0, 1.0)), (b - a).normalized()]
		d -= _lengths[i]
	return [route[0], Vector3.FORWARD]


func _physics_process(delta: float) -> void:
	if route.size() < 2:
		return
	_hurt_rest = maxf(_hurt_rest - delta, 0.0)
	# How sharp the bends ahead are: it brakes for each in time to come into it at its speed (what it may go at now
	# is the slowest of: each bend's speed, plus what braking at BRAKE over the road to it takes off)
	var pull: float = KIND_PULL.get(kind, 1.0)
	var want := cruise
	var turning := 0.0
	# (each point of the road from its rear bumper (it is out of a bend only when all of it is) to 44 m past its front:
	# the bend measured there may start 4 m before it)
	var look := -half_size.z * 2.0 - 4.0
	while look <= 44.0:
		var sharp := bend_at(along + look + half_size.z)
		if absf(look) < 0.1:
			turning = sharp
		want = minf(want, sqrt(pow(lerpf(cruise, corner_speed, sharp), 2.0) + 2.0 * BRAKE * pull * maxf(look - 4.0, 0.0)))
		look += 2.0
	# (the bend its front is in, for tests)
	bend_sharp = bend_at(along + half_size.z)
	bend_speed = lerpf(cruise, corner_speed, bend_sharp)
	# ...climbing, a little slower; going down steeply into a bend, slower still (the grade: up is positive)
	var grade := sin(_pitch)
	if grade > 0.0:
		want *= 1.0 - clampf(grade * 1.6, 0.0, 0.35)
	else:
		want *= 1.0 - clampf(-grade * 0.6, 0.0, 0.15) - clampf(-grade * 1.5, 0.0, 0.3) * turning
	# ...now and then it stops: a bus at its stops (or every so often), anything else as at a junction
	if kind == &"bus" and not stops.is_empty():
		for at in stops:
			var to := fposmod(at - along, _total)
			if to < 0.6 and absf(_stopped_at - at) > 0.01 and _stop_left <= 0.0:
				_stop_left = randf_range(4.0, 6.0)
				_stopped_at = at
	else:
		_stop_wait -= delta
		if _stop_wait <= 0.0:
			_stop_left = randf_range(4.0, 6.0) if kind == &"bus" else randf_range(1.5, 3.0)
			_stop_wait = randf_range(14.0, 24.0) if kind == &"bus" else randf_range(12.0, 25.0)
	if _stop_left > 0.0:
		_stop_left -= delta
		want = 0.0
	# ...and keeps back from whatever is ahead of it on its road
	want = minf(want, _room_ahead())
	speed = move_toward(speed, want, (PULL * pull if want > speed else BRAKE * pull * 1.3) * delta)
	along = fposmod(along + speed * delta, _total)
	_place(delta)
	_bump()
	_light_look -= delta
	if _light_look <= 0.0:
		_light_look = 0.5
		_set_lights()


## How sharp the road is at `distance` along its loop, 0 (straight) .. 1 (a hairpin, about 9 m round): the turn between
## the 4 m chords either side of it (chords, not the road's segments, so where its points fall does not matter).
func bend_at(distance: float) -> float:
	var here: Vector3 = point_at(distance)[0]
	var back := here - (point_at(distance - 4.0)[0] as Vector3)
	var on := (point_at(distance + 4.0)[0] as Vector3) - here
	back.y = 0.0
	on.y = 0.0
	if back.length_squared() < 0.01 or on.length_squared() < 0.01:
		return 0.0
	return clampf(back.angle_to(on) / 0.45, 0.0, 1.0)


## The speed it may go at for what is ahead of it on its road: closing on the one in front, to its speed at GAP.
func _room_ahead() -> float:
	var most := INF
	for node in get_tree().get_nodes_in_group(&"cars"):
		var other := node as HazardCar
		if other == null or other == self or other.road != road:
			continue
		var gap := fposmod(other.along - along, _total) - half_size.z - other.half_size.z
		# (no faster than it could brake to the one in front's speed by GAP)
		most = minf(most, sqrt(other.speed * other.speed + 2.0 * BRAKE * 0.7 * maxf(gap - GAP, 0.0)))
	return most


## Where it is on its road, and how it sits on it: each wheel feels down for the road, and the body goes to the height
## of its wheels, pitched and rolled to the ground under them.
func _place(delta: float) -> void:
	var at: Array = point_at(along)
	# (it turns as the road does, looking a little ahead so it rounds the corners; a long one looks further)
	var reach := 1.0 + half_size.z * 0.4
	var look: Vector3 = (point_at(along + reach)[0] as Vector3) - (point_at(along - reach)[0] as Vector3)
	look.y = 0.0
	var yaw := atan2(look.x, look.z) if look.length() > 0.01 else rotation.y
	var level := Basis(Vector3.UP, yaw)
	var middle: Vector3 = at[0]
	# Each wheel's road: straight down under where it is (past the other cars and himself)
	var ground: Array[float] = []
	var space := get_world_3d().direct_space_state if is_inside_tree() else null
	var skip: Array[RID] = []
	for node in get_tree().get_nodes_in_group(&"cars"):
		skip.append((node as CollisionObject3D).get_rid())
	if player:
		skip.append(player.get_rid())
	for k in _wheels.size():
		var foot := middle + level * Vector3(_wheel_rest[k].x, 0.0, _wheel_rest[k].z)
		var y := middle.y
		if space:
			var query := PhysicsRayQueryParameters3D.create(foot + Vector3.UP * 2.5, foot + Vector3.DOWN * 4.0, 1)
			query.exclude = skip
			var hit := space.intersect_ray(query)
			if not hit.is_empty():
				y = (hit.position as Vector3).y
		ground.append(y)
	# The plane its wheels make: how high, how pitched (front up is positive), how rolled (left up is positive)
	var front := 0.0
	var back := 0.0
	var left := 0.0
	var right := 0.0
	var fz := 0.0
	var bz := 0.0
	var half_track := 0.5
	var counts := Vector4.ZERO
	for k in _wheels.size():
		var rest := _wheel_rest[k]
		if rest.z > 0.0:
			front += ground[k]
			fz += rest.z
			counts.x += 1.0
		else:
			back += ground[k]
			bz += rest.z
			counts.y += 1.0
		if rest.x > 0.0:
			left += ground[k]
			counts.z += 1.0
		else:
			right += ground[k]
			counts.w += 1.0
		half_track = absf(rest.x)
	var height := middle.y
	var pitch := 0.0
	var roll := 0.0
	if counts.x > 0.0 and counts.y > 0.0 and counts.z > 0.0 and counts.w > 0.0:
		front /= counts.x
		back /= counts.y
		fz /= counts.x
		bz /= counts.y
		pitch = atan2(front - back, fz - bz)
		roll = atan2(left / counts.z - right / counts.w, half_track * 2.0)
		# (the middle's height on the line from the back wheels to the front)
		height = lerpf(back, front, -bz / (fz - bz))
	# Smoothed, so a lump in the road is ridden, not jumped to (but put straight down where it starts)
	var follow := 1.0 - exp(-22.0 * delta) if _settled else 1.0
	_settled = true
	_pitch = lerpf(_pitch, pitch, follow)
	_roll = lerpf(_roll, roll, follow)
	_height = lerpf(_height, height, follow)
	var sat := level * Basis(Vector3.RIGHT, -_pitch) * Basis(Vector3.BACK, _roll)
	global_transform = Transform3D(sat, Vector3(middle.x, _height, middle.z))
	# Each wheel up or down to its own road, a little (the springs), steering, turning with the way gone
	var dt := maxf(delta, 0.0001)
	_yaw_rate = angle_difference(_yaw_was, yaw) / dt if delta > 0.0 else 0.0
	_yaw_was = yaw
	var wheelbase := maxf(fz - bz, 1.0)
	var steer := clampf(atan(wheelbase * _yaw_rate / maxf(speed, 1.5)), -0.55, 0.55)
	_wheel_spin += speed * delta / _wheel_radius
	contact_error = 0.0
	for k in _wheels.size():
		var on_body := global_transform * Vector3(_wheel_rest[k].x, 0.0, _wheel_rest[k].z)
		var off := clampf(ground[k] - on_body.y, -TRAVEL, TRAVEL)
		# (a wheel's spring is quick: it follows its road at once, within its travel; the body is what is smoothed)
		_wheel_ride[k] = off
		_wheels[k].position = _wheel_rest[k] + Vector3.UP * _wheel_ride[k]
		_wheels[k].rotation = Vector3(_wheel_spin, steer if _wheel_front[k] else 0.0, 0.0)
		var under := (global_transform * (_wheel_rest[k] + Vector3.UP * (_wheel_ride[k] - _wheel_radius))).y
		contact_error = maxf(contact_error, absf(under - ground[k]))
	# The body leans out in a turn and dips its nose braking (its wheels and box stay as they are)
	if _body:
		var accel := (speed - _speed_was) / dt
		_speed_was = speed
		var want := Vector2(clampf(-accel * 0.006, -0.04, 0.04), clampf(-speed * _yaw_rate * 0.01, -0.06, 0.06))
		_lean = _lean.lerp(want, 1.0 - exp(-6.0 * dt))
		_body.rotation = Vector3(_lean.x, 0.0, _lean.y)


## Run into by its front: hurt and thrown aside.
func _bump() -> void:
	if player == null or _hurt_rest > 0.0 or speed < 1.0:
		return
	var local := global_transform.affine_inverse() * player.global_position
	# (in front of it, at road level: not on its roof)
	if absf(local.x) < half_size.x + 0.15 and local.z > half_size.z - 0.4 and local.z < half_size.z + 0.9 and local.y < 1.0:
		_hurt_rest = 1.0
		Hazards.hurt(self, global_position)
		var away := global_basis.z * (6.0 + speed * 0.4) + global_basis.x * signf(local.x if local.x != 0.0 else 1.0) * 3.0
		player.velocity = Vector3(away.x, 6.0, away.z)


# --- Lights ---------------------------------------------------------------------------------------------------------

## The lamps, signs and tail lights drawn lit, whatever the light falling on them.
func _glow(model: Node3D) -> void:
	var lit := {"lamp": Color(1.0, 0.97, 0.82), "tail": Color(1.0, 0.14, 0.1), "sign": Color(1.0, 0.95, 0.6)}
	for part: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		for surface in part.mesh.get_surface_count():
			var original := part.mesh.surface_get_material(surface)
			if original == null or not lit.has(original.resource_name):
				continue
			var bright := StandardMaterial3D.new()
			bright.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			bright.albedo_color = lit[original.resource_name]
			part.set_surface_override_material(surface, bright)


## Beams and a tail light (only lit on the nearest few, at night), and a cone of light ahead of it (every one, at night).
func _make_lights() -> void:
	var lamp_y := clampf(half_size.y * 2.0 * 0.45, 0.6, 0.9)
	for side in [-1.0, 1.0]:
		var beam := SpotLight3D.new()
		beam.position = Vector3(side * (half_size.x - 0.3), lamp_y, half_size.z + 0.05)
		# (looking ahead and a little down at the road)
		beam.rotation = Vector3(-0.12, PI, 0.0)
		beam.light_color = Color(1.0, 0.94, 0.78)
		beam.light_energy = 9.0
		beam.spot_range = 26.0
		beam.spot_angle = 28.0
		beam.spot_attenuation = 0.8
		beam.visible = false
		add_child(beam)
		_beams.append(beam)
	_tail_light = OmniLight3D.new()
	_tail_light.position = Vector3(0.0, lamp_y, -half_size.z - 0.3)
	_tail_light.light_color = Color(1.0, 0.12, 0.08)
	_tail_light.light_energy = 1.4
	_tail_light.omni_range = 3.5
	_tail_light.visible = false
	add_child(_tail_light)
	# The cone: a soft fan of light on the air ahead, brightest at the lamps
	var cone := CylinderMesh.new()
	cone.top_radius = 0.25
	cone.bottom_radius = 2.2
	cone.height = 7.0
	cone.radial_segments = 12
	cone.rings = 1
	cone.cap_top = false
	cone.cap_bottom = false
	var air := ShaderMaterial.new()
	air.shader = _cone_shader()
	cone.material = air
	_cones = MeshInstance3D.new()
	_cones.mesh = cone
	_cones.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# (laid along +Z, its narrow end at the lamps, a little down)
	_cones.transform = Transform3D(Basis(Vector3.RIGHT, PI * 0.5 + 0.08).scaled(Vector3(half_size.x / 0.85, 1.0, 0.55)),
			Vector3(0.0, lamp_y, half_size.z + 3.5))
	_cones.visible = false
	add_child(_cones)


static var _cone: Shader


static func _cone_shader() -> Shader:
	if _cone == null:
		_cone = Shader.new()
		_cone.code = """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
void fragment() {
	// (UV.y runs along the cone: bright at the lamps, gone at its end; softer at its edges)
	float along = 1.0 - UV.y;
	float edge = abs(dot(NORMAL, VIEW));
	ALBEDO = vec3(1.0, 0.92, 0.7) * 0.22 * along * along * edge;
}
"""
	return _cone


## Whether it is night (lights on), and if so whether this one is among the nearest LIT to him (real beams).
func _set_lights() -> void:
	var dark := lights
	if dark < 0.0:
		dark = DayNight.current.night if DayNight.current else 0.0
	var on := dark > 0.5
	_cones.visible = on
	var near := false
	if on and player:
		var mine := global_position.distance_squared_to(player.global_position)
		var closer := 0
		for node in get_tree().get_nodes_in_group(&"cars"):
			if node != self and (node as Node3D).global_position.distance_squared_to(player.global_position) < mine:
				closer += 1
		near = closer < LIT
	for beam in _beams:
		beam.visible = near
	_tail_light.visible = near
