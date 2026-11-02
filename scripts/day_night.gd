class_name DayNight
extends Node
## The day going round (the user, 2026-11-02: "there needs to be a day and night cycle"): dawn, the summer day the
## hill had before (midday as it was), a golden evening, a blue moonlit night still bright enough to play in, dawn
## again, once every `DAY_SECONDS`. The sun and moon cross the sky (GameCommon weather's Daylight paths and its sky
## shader, with stars); World's sun light, the ambient light and the fog follow; the far hills and the puff clouds
## take the hour's tint. At night the windows light, lamps come on along the poles and fireflies come out in the grove.
##
## And how dangerous it is out (the user: "day is more dangerous, more cars, and hawks can easily see you, and more
## people"): `danger` is 1 by day and 0 at night; the hunters read it (`by_day`): more cars and people about by day,
## who see him from further, the hawk out by day and the owl by night, the crows roosting at night.
##
##   DayNight.place(world)        # once the world model, its sun and its environment are in

## How long a whole day takes (s), and the hour a game starts at (Claude's picks).
const DAY_SECONDS := 14.0 * 60.0
const START_HOUR := 10.0
## The hour's colours, from midnight round: hour, sky overhead, sky at the horizon, the light's colour and strength
## (the sun's, or by night the moon's), the ambient light's colour and strength, and the far hills' and clouds' tint.
const KEYS := [
	[0.0, Color(0.03, 0.06, 0.16), Color(0.12, 0.17, 0.32), Color(0.62, 0.72, 1.0), 0.32, Color(0.28, 0.36, 0.64), 0.8, Color(0.34, 0.4, 0.62)],
	[5.0, Color(0.03, 0.06, 0.16), Color(0.12, 0.17, 0.32), Color(0.62, 0.72, 1.0), 0.32, Color(0.28, 0.36, 0.64), 0.8, Color(0.34, 0.4, 0.62)],
	[6.1, Color(0.2, 0.26, 0.5), Color(0.95, 0.62, 0.48), Color(1.0, 0.62, 0.42), 0.6, Color(0.5, 0.48, 0.6), 0.85, Color(0.86, 0.7, 0.74)],
	[7.5, Color(0.2, 0.44, 0.8), Color(0.82, 0.86, 0.9), Color(1.0, 0.9, 0.78), 1.0, Color(0.6, 0.68, 0.82), 0.8, Color(1.0, 0.98, 0.97)],
	[12.0, Color(0.16, 0.42, 0.82), Color(0.7, 0.84, 0.94), Color(1.0, 0.96, 0.86), 1.15, Color(0.62, 0.72, 0.86), 0.8, Color(1.0, 1.0, 1.0)],
	[16.0, Color(0.17, 0.42, 0.8), Color(0.76, 0.84, 0.9), Color(1.0, 0.93, 0.8), 1.1, Color(0.64, 0.7, 0.82), 0.8, Color(1.0, 0.98, 0.95)],
	[17.4, Color(0.22, 0.36, 0.68), Color(1.0, 0.72, 0.45), Color(1.0, 0.7, 0.42), 0.95, Color(0.66, 0.58, 0.6), 0.8, Color(1.0, 0.84, 0.72)],
	[18.1, Color(0.12, 0.14, 0.36), Color(0.85, 0.45, 0.42), Color(0.95, 0.5, 0.45), 0.45, Color(0.42, 0.38, 0.55), 0.85, Color(0.62, 0.5, 0.62)],
	[19.0, Color(0.03, 0.06, 0.16), Color(0.12, 0.17, 0.32), Color(0.62, 0.72, 1.0), 0.32, Color(0.28, 0.36, 0.64), 0.8, Color(0.34, 0.4, 0.62)],
	[24.0, Color(0.03, 0.06, 0.16), Color(0.12, 0.17, 0.32), Color(0.62, 0.72, 1.0), 0.32, Color(0.28, 0.36, 0.64), 0.8, Color(0.34, 0.4, 0.62)],
]
## Lamps along the poles that really light (the nearest to him; the rest only glow), and how far each reaches.
const LIT_LAMPS := 4
const LAMP_REACH := 7.0

## The day now, for anything that asks (null: there is no day going round, as in a test yard).
static var current: DayNight

## The hour (0..24), how dark it is (0 day .. 1 night) and how dangerous it is out (1 day .. 0 night).
var hour := START_HOUR
var night := 0.0
var danger := 1.0
## Stopped (tests, or the clock held): the hour stays where it is put.
var held := false

var world: World
var _sun: DirectionalLight3D
var _environment: Environment
var _sky: ShaderMaterial
var _far: Array[StandardMaterial3D] = []
var _far_colour: Array[Color] = []
var _windows: Array[ShaderMaterial] = []
var _window_colour: Array[Color] = []
## Each window material's own glow by day (the far town's lit windows glow a little always; houses' glass not).
var _window_glow: Array[float] = []
## The houses' glass that is lit at night (about two houses in three: the rest are dark, out or asleep).
var _lit_glass: ShaderMaterial
var lit_houses := 0
var _lamp_spots := PackedVector3Array()
var _lamp_glow: GeometryInstance3D
var _lamps: Array[OmniLight3D] = []
var _lamp_look := 0.0
var _flies: CPUParticles3D
var _dial: DayDial


static func place(world: World) -> DayNight:
	var day := DayNight.new()
	day.name = "DayNight"
	day.world = world
	world.add_child(day)
	current = day
	day._take_over()
	day.set_hour(START_HOUR)
	return day


## How much of `day_value` to `night_value` it is now (by `danger`); `otherwise` with no day going round.
static func by_day(day_value: float, night_value: float, otherwise := 1.0) -> float:
	if current == null or not is_instance_valid(current):
		return otherwise
	return lerpf(night_value, day_value, current.danger)


## Whether it is night enough for the night's creatures (the owl) and not the day's (the hawk): with no day going
## round, both are about.
static func is_night() -> bool:
	return current != null and is_instance_valid(current) and current.danger < 0.35


static func is_day() -> bool:
	return current == null or not is_instance_valid(current) or current.danger > 0.3


func _exit_tree() -> void:
	if current == self:
		current = null


## Sets the hour now (and everything that follows it).
func set_hour(to: float) -> void:
	hour = fposmod(to, 24.0)
	_apply()


func _process(delta: float) -> void:
	if not held:
		hour = fposmod(hour + delta * 24.0 / DAY_SECONDS, 24.0)
	_apply()
	_lamp_look -= delta
	if _lamp_look <= 0.0:
		_lamp_look = 0.5
		_light_nearest_lamps()
		_traffic()


## What the world set up for its one summer afternoon: its sun, its environment (with GameCommon weather's sky in
## place of the plain one), the far hills' and the windows' materials; and the lamps and fireflies.
func _take_over() -> void:
	for node in world.get_children():
		if node is DirectionalLight3D and _sun == null:
			_sun = node
		elif node is WorldEnvironment:
			_environment = (node as WorldEnvironment).environment
	_sky = Daylight.make_sky_material()
	_sky.set_shader_parameter(&"cloud_cover", 0.0)
	_sky.set_shader_parameter(&"ground", Color(0.36, 0.5, 0.4))
	if _environment:
		_environment.sky.sky_material = _sky
	var seen := {}
	for mesh: MeshInstance3D in world.find_children("*", "MeshInstance3D", true, false):
		if mesh.mesh == null:
			continue
		for k in mesh.mesh.get_surface_count():
			var material := mesh.get_surface_override_material(k)
			var original := mesh.mesh.surface_get_material(k)
			if material is ShaderMaterial and original != null and original.resource_name == "glass" and hash(String(mesh.name)) % 3 != 0:
				if _lit_glass == null:
					_lit_glass = material.duplicate()
					_windows.append(_lit_glass)
					var glass: Variant = _lit_glass.get_shader_parameter(&"albedo")
					_window_colour.append(glass if glass is Color else Color.WHITE)
					_window_glow.append(0.0)
				mesh.set_surface_override_material(k, _lit_glass)
				lit_houses += 1
				continue
			if material == null or seen.has(material):
				continue
			seen[material] = true
			# (the far hills and the volcano: unshaded, out of the fog: World._dress)
			if material is StandardMaterial3D and (material as StandardMaterial3D).disable_fog \
					and (material as StandardMaterial3D).shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED:
				_far.append(material)
				_far_colour.append((material as StandardMaterial3D).albedo_color)
			# (the windows: the world shader's, glowing)
			elif material is ShaderMaterial and float((material as ShaderMaterial).get_shader_parameter(&"emission") if (material as ShaderMaterial).get_shader_parameter(&"emission") != null else 0.0) > 0.0:
				_windows.append(material)
				var colour: Variant = (material as ShaderMaterial).get_shader_parameter(&"albedo")
				_window_colour.append(colour if colour is Color else Color.WHITE)
				_window_glow.append(0.9)
	_make_lamps()
	_make_flies()
	_dial = DayDial.new()
	_dial.day = self
	var layer := CanvasLayer.new()
	layer.layer = 2
	layer.add_child(_dial)
	add_child(layer)


func _apply() -> void:
	var path := Daylight.at(hour)
	var sun_dir: Vector3 = path.sun_dir
	night = clampf(1.0 - smoothstep(-0.08, 0.12, sun_dir.y), 0.0, 1.0)
	danger = smoothstep(-0.02, 0.3, sun_dir.y)
	var i := 0
	while i < KEYS.size() - 2 and hour >= KEYS[i + 1][0]:
		i += 1
	var a: Array = KEYS[i]
	var b: Array = KEYS[i + 1]
	var t := smoothstep(0.0, 1.0, (hour - a[0]) / (b[0] - a[0]))
	var zenith := (a[1] as Color).lerp(b[1], t)
	var horizon := (a[2] as Color).lerp(b[2], t)
	var light := (a[3] as Color).lerp(b[3], t)
	var energy := lerpf(a[4], b[4], t)
	var ambient := (a[5] as Color).lerp(b[5], t)
	var ambient_energy := lerpf(a[6], b[6], t)
	var tint := (a[7] as Color).lerp(b[7], t)
	if _sky:
		_sky.set_shader_parameter(&"zenith", zenith)
		_sky.set_shader_parameter(&"horizon", horizon)
		_sky.set_shader_parameter(&"sun_dir", sun_dir)
		_sky.set_shader_parameter(&"moon_dir", path.moon_dir)
		_sky.set_shader_parameter(&"sun_color", light)
		_sky.set_shader_parameter(&"night", night)
	if _sun:
		# (the sun while it is up, then the moon)
		Daylight.aim(_sun, path.light_dir)
		_sun.light_color = light
		_sun.light_energy = energy
	if _environment:
		_environment.ambient_light_color = ambient
		_environment.ambient_light_energy = ambient_energy
		_environment.fog_light_color = horizon
	for k in _far.size():
		_far[k].albedo_color = _far_colour[k] * tint
	var clouds := world.get_node_or_null(^"PuffClouds") as PuffClouds
	if clouds == null:
		for node in world.get_children():
			if node is PuffClouds:
				clouds = node
	if clouds and clouds.material:
		clouds.material.set_shader_parameter(&"sun_dir", sun_dir if sun_dir.y > 0.0 else (path.moon_dir as Vector3))
		clouds.material.set_shader_parameter(&"lit_color", Color(1.0, 0.98, 0.94).lerp(light, 0.45) * lerpf(1.0, 0.5, night))
		clouds.material.set_shader_parameter(&"shade_color", Color(0.62, 0.7, 0.84) * tint)
		clouds.material.set_shader_parameter(&"haze_color", horizon)
	# (lit windows by night: warm, and brighter)
	for k in _windows.size():
		_windows[k].set_shader_parameter(&"albedo", _window_colour[k].lerp(Color(1.0, 0.82, 0.48), night))
		_windows[k].set_shader_parameter(&"emission", lerpf(_window_glow[k], 1.4, night))
	if _lamp_glow:
		_lamp_glow.visible = night > 0.35
	if _flies:
		_flies.emitting = night > 0.6


## A lamp on each pole, under where the phone line meets it (the wires' ends), its head turned in towards the hill.
func _make_lamps() -> void:
	var tops := {}
	var k := 0
	while world.markers.has("wire_%d_a" % k):
		for end: String in ["a", "b"]:
			var at: Vector3 = (world.markers["wire_%d_%s" % [k, end]] as Transform3D).origin
			var cell := Vector2i(roundi(at.x * 2.0), roundi(at.z * 2.0))
			# (the lowest wire on each pole: the phone line, under the crossarm)
			if not tops.has(cell) or at.y < (tops[cell] as Vector3).y:
				tops[cell] = at
		k += 1
	var heart: Vector3 = (world.markers["grove_heart"] as Transform3D).origin if world.markers.has("grove_heart") else Vector3.ZERO
	for at: Vector3 in tops.values():
		var inward := Vector3(heart.x - at.x, 0.0, heart.z - at.z).normalized()
		_lamp_spots.append(at + inward * 0.45 + Vector3.DOWN * 0.9)
	if _lamp_spots.is_empty():
		return
	# (every lamp's glowing head, one MultiMesh)
	var bulb := SphereMesh.new()
	bulb.radius = 0.13
	bulb.height = 0.2
	bulb.radial_segments = 8
	bulb.rings = 4
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.albedo_color = Color(1.0, 0.86, 0.55)
	bulb.material = glow
	var many := MultiMesh.new()
	many.transform_format = MultiMesh.TRANSFORM_3D
	many.mesh = bulb
	many.instance_count = _lamp_spots.size()
	for n in _lamp_spots.size():
		many.set_instance_transform(n, Transform3D(Basis.IDENTITY, _lamp_spots[n]))
	var heads := MultiMeshInstance3D.new()
	heads.multimesh = many
	heads.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(heads)
	_lamp_glow = heads
	for n in LIT_LAMPS:
		var lamp := OmniLight3D.new()
		lamp.light_color = Color(1.0, 0.82, 0.55)
		lamp.light_energy = 1.4
		lamp.omni_range = LAMP_REACH
		lamp.visible = false
		world.add_child(lamp)
		_lamps.append(lamp)


## The lamps nearest him really light (at night).
func _light_nearest_lamps() -> void:
	if _lamps.is_empty() or world.player == null:
		return
	var him := world.player.global_position
	var order := Array(_lamp_spots)
	order.sort_custom(func(p: Vector3, q: Vector3) -> bool: return p.distance_squared_to(him) < q.distance_squared_to(him))
	for n in _lamps.size():
		var on := night > 0.35 and n < order.size()
		_lamps[n].visible = on
		if on:
			_lamps[n].global_position = order[n] + Vector3.DOWN * 0.2


## Fewer about at night (the user, 2026-11-02, "day is more dangerous, more cars ... and more people"): by day every
## car on every road and everyone out walking; at night one car to a road, and half the people gone indoors. Only
## out of his sight (40 m off) do they go or come back, so none vanishes or appears in front of him. Those put
## away have the meta `put_away_by_night`.
const NIGHT_CARS := 1
const OUT_OF_SIGHT := 40.0

func _traffic() -> void:
	if world.player == null:
		return
	var him := world.player.global_position
	var on_road := {}
	for node in get_tree().get_nodes_in_group(&"cars"):
		var car := node as Node3D
		var road: int = car.get(&"road") if car.get(&"road") != null else 0
		var k: int = on_road.get(road, 0)
		on_road[road] = k + 1
		var out := k < roundi(lerpf(NIGHT_CARS, Hazards.CARS_PER_LOOP, danger))
		_put(car, out, him)
	var n := 0
	for node in get_tree().get_nodes_in_group(&"people"):
		n += 1
		_put(node as Node3D, danger > 0.35 or n % 2 == 1, him)


func _put(thing: Node3D, out: bool, him: Vector3) -> void:
	var away := thing.has_meta(&"put_away_by_night")
	if out == not away or thing.global_position.distance_to(him) < OUT_OF_SIGHT:
		return
	if out:
		thing.remove_meta(&"put_away_by_night")
		thing.visible = true
		thing.process_mode = Node.PROCESS_MODE_INHERIT
		if thing is CollisionObject3D:
			(thing as CollisionObject3D).collision_layer = thing.get_meta(&"night_layer", 1)
			thing.remove_meta(&"night_layer")
	else:
		thing.set_meta(&"put_away_by_night", true)
		thing.visible = false
		thing.process_mode = Node.PROCESS_MODE_DISABLED
		if thing is CollisionObject3D:
			thing.set_meta(&"night_layer", (thing as CollisionObject3D).collision_layer)
			(thing as CollisionObject3D).collision_layer = 0


## Fireflies over the grove at night.
func _make_flies() -> void:
	if not world.markers.has("grove_heart"):
		return
	_flies = CPUParticles3D.new()
	_flies.amount = 60
	_flies.lifetime = 5.0
	_flies.preprocess = 5.0
	_flies.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_flies.emission_box_extents = Vector3(18.0, 1.2, 18.0)
	_flies.direction = Vector3.UP
	_flies.spread = 180.0
	_flies.initial_velocity_min = 0.05
	_flies.initial_velocity_max = 0.3
	_flies.gravity = Vector3.ZERO
	_flies.scale_amount_min = 0.6
	_flies.scale_amount_max = 1.2
	var twinkle := Curve.new()
	twinkle.add_point(Vector2(0.0, 0.0))
	twinkle.add_point(Vector2(0.2, 1.0))
	twinkle.add_point(Vector2(0.45, 0.2))
	twinkle.add_point(Vector2(0.7, 1.0))
	twinkle.add_point(Vector2(1.0, 0.0))
	_flies.scale_amount_curve = twinkle
	var fly := SphereMesh.new()
	fly.radius = 0.035
	fly.height = 0.07
	fly.radial_segments = 6
	fly.rings = 3
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.albedo_color = Color(0.85, 1.0, 0.45)
	fly.material = glow
	_flies.mesh = fly
	_flies.emitting = false
	_flies.position = (world.markers["grove_heart"] as Transform3D).origin + Vector3.UP * 1.4
	world.add_child(_flies)


## The HUD's dial of the day: the sun or the moon going round over a little sky, day above and night below (no words:
## symbols, as every control is). Top right, under the pause button.
class DayDial extends Control:
	var day: DayNight

	func _ready() -> void:
		set_anchors_preset(Control.PRESET_TOP_RIGHT)
		offset_left = -86
		offset_right = -22
		offset_top = 92
		offset_bottom = 156
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.46
		var ink := UiStyle.BARK
		# (framed like the HUD's badges: a soft shadow, a bark rim round a wooden ring: UiStyle)
		draw_circle(c + Vector2(0.0, 3.0), r + 7.0, Color(0.0, 0.0, 0.0, 0.3))
		draw_circle(c, r + 7.0, ink)
		draw_circle(c, r + 5.0, UiStyle.WOOD)
		draw_circle(c, r + 2.0, ink)
		draw_circle(c, r, Color(0.08, 0.1, 0.25))
		# (the day's half of the sky above, the night's below; the hour turns the dial so now is at the top)
		var turn := (day.hour - 12.0) / 24.0 * TAU
		var arc := PackedVector2Array([c])
		for k in 25:
			var a := -PI + turn + PI * k / 24.0
			arc.append(c + Vector2(cos(a), sin(a)) * r)
		draw_colored_polygon(arc, Color(0.45, 0.72, 0.95))
		var sun_at := c + Vector2(0.0, -r * 0.5)
		# (whichever is up shows at the top: the sun by day, the moon by night)
		if day.night < 0.5:
			for k in 8:
				var ray := Vector2.from_angle(TAU * k / 8.0)
				draw_line(sun_at + ray * r * 0.33, sun_at + ray * r * 0.45, Color(1.0, 0.85, 0.3), 2.5)
			draw_circle(sun_at, r * 0.3, ink)
			draw_circle(sun_at, r * 0.26, Color(1.0, 0.85, 0.3))
		else:
			draw_circle(sun_at, r * 0.26, Color(0.92, 0.94, 1.0))
			draw_circle(sun_at + Vector2(r * 0.11, -r * 0.06), r * 0.22, Color(0.08, 0.1, 0.25))
		draw_arc(c, r - 1.0, 0.0, TAU, 40, Color(1.0, 1.0, 1.0, 0.25), 2.0)
