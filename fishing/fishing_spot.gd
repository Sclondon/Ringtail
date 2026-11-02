class_name FishingSpot
extends Node3D
## A place to fish from (GameCommon godot/fishing; from Gloaming's Fishing minigame, 2026-10-29: "The lake needs a
## fishing minigame, and so should the dock"; made a component for Ringtail's grove pond, 2026-11-02). Its origin is
## where he stands, facing +z out over the water. The game starts it (`begin`: a keeper, a button, whatever it likes)
## and hears how it goes (`caught`, `lost`, `ended`); it knows nothing of the game beyond its Player and the water.
##
##   Cast    hold the main button and let go: the longer it is held, the further out the bobber goes (the power
##           swings up and down while it is held).
##   Wait    fish shadows wander about under the water; one comes to the bobber and nibbles it (the bobber
##           twitches) once or a few times, then bites: the bobber goes under.
##   Hook    press as it goes under (not before: a nibble struck at frightens the fish off).
##   Reel    hold to reel in, which pulls the line tight; let go to let it slacken. The fish fights in runs: reel
##           through a run and the line snaps, let it go slack too long and it throws the hook. Brought in close,
##           it is landed.
##
## Each catch is weighed (`caught`), the biggest kept as the spot's best (user://fishing.cfg, by `id`). The quit button
## (or a quit action) puts the rod away. The rod is held as the character controller holds a long gun
## (CharacterRig._hold_gun asks FishingRod.held_at).

signal started
signal ended
## A fish landed: its kind's name, its weight (kg), and whether it is the spot's heaviest yet.
signal caught(kind: String, weight: float, record: bool)
## One got away: why ("snapped", "threw", "ran", "bait", "early").
signal lost(why: String)

enum Stage { READY, CHARGING, FLYING, WAITING, NIBBLE, BITE, FIGHT, LANDED }

const PIECES := "res://fishing/fishing.glb"
const BESTS := "user://fishing.cfg"
## [model, name, least kg, most kg, how hard it pulls (0..1), how common]
const LAKE_FISH := [["trout", "Trout", 0.4, 2.6, 0.5, 5.0], ["perch", "Perch", 0.2, 1.2, 0.35, 5.0],
		["pike", "Pike", 2.0, 9.0, 0.85, 2.0]]
const SEA_FISH := [["mackerel", "Mackerel", 0.3, 1.5, 0.45, 5.0], ["snapper", "Red Snapper", 1.0, 6.0, 0.65, 3.0],
		["cod", "Cod", 2.0, 12.0, 0.8, 2.0]]
const POND_FISH := [["koi", "Koi", 0.5, 3.5, 0.45, 5.0], ["carp", "Carp", 0.8, 6.0, 0.65, 3.0],
		["bluegill", "Bluegill", 0.1, 0.6, 0.3, 5.0], ["catfish", "Catfish", 1.0, 8.0, 0.8, 2.0],
		["goldkoi", "Golden Koi", 1.0, 4.0, 0.7, 0.4]]

## What it is called (on its panel) and its name for its best.
@export var title := "Fishing"
@export var id := "fishing"
## The fish here (as LAKE_FISH), how far the bobber goes (least, most: m), and how far out the water is deep enough.
var kinds: Array = POND_FISH
@export var cast_range := Vector2(5.0, 16.0)
@export var deep_from := 4.0
## How many fish shadows swim about, and how far out from the spot (m) they wander.
@export var shadows := 7
@export var wander := Vector2(7.0, 5.0)
## How big the rod is (1: a man's), and how far his hands go (1: the boy's reach; less for a smaller figure).
@export var rod_size := 1.0
@export var hold_scale := 1.0
## How long a bite lasts before the fish lets go, and how long the line may lie slack in a fight (s).
@export var bite_time := 0.9
@export var slack_time := 2.6
## The actions that do what the main button does, and that put the rod away (each optional: the buttons are on
## screen anyway).
@export var main_actions: Array[StringName] = [&"act"]
@export var quit_actions: Array[StringName] = [&"duck"]

## Who fishes, and the camera behind him (optional: `look_along` and `snap` if it has them).
var player: Player
var camera: Node
## The water's height where there is no `water_at` to ask; `water_at(x, z) -> float` (optional: a sea's tide and
## waves); `is_water(x, z) -> bool` (optional: whether there is water there, deep enough to fish).
var water_level := 0.0
var water_at: Callable
var is_water: Callable
## Optional: `say(text)` for what happens ("Hooked!"), and `should_stop() -> String` asked each step (a reason to put
## the rod away, such as a foe coming; "" to go on).
var say: Callable
var should_stop: Callable
## How the catch is held up to see (the way the rod points, as the moves below): the man holds it high; a small
## figure with a short rod holds it out ahead at about his eyes.
var land_point := LAND_POINT
## Pressed by a test in place of the button.
var test_hold := false

var running := false
var time := 0.0
var stage := Stage.READY
var distance := 0.0
var tension := 0.0
var hud: FishingHud
var _stage_time := 0.0
var _power := 0.0
var _held := false
var _rod: FishingRod
var _grip := Vector3.ZERO
var _point := Vector3.FORWARD
var _bend := 0.0
var _bobber: Node3D
var _line: MeshInstance3D
var _from := Vector3.ZERO
var _bob_at := Vector3.ZERO
var _shadows: Array[Node3D] = []
var _goals: Array[Vector3] = []
var _taker := -1
var _nibbles := 0
var _next_nibble := 0.0
var _fish: Array = []
var _weight := 0.0
var _pull := 0.0
var _start_distance := 0.0
var _slack := 0.0
var _surging := false
var _surge_time := 0.0
var _landed: Node3D
var _caught := 0
var _biggest := 0.0
static var _pieces: Node


## A copy of piece `name` of `pieces` (fishing.glb), shaded as the character controller's things are (Toon).
static func piece(pieces: Node, name: String) -> Node3D:
	var found := pieces.find_child(name, true, false) as Node3D
	var model := found.duplicate() as Node3D
	model.transform = Transform3D.IDENTITY
	Toon.apply(model)
	return model


## The pieces (fishing.glb), loaded once.
static func pieces() -> Node:
	if _pieces == null:
		_pieces = (load(PIECES) as PackedScene).instantiate()
	return _pieces


## The best kept for spot `spot_id` (kg), or -1.
static func best(spot_id: String) -> float:
	var saved := ConfigFile.new()
	if saved.load(BESTS) != OK:
		return -1.0
	return float(saved.get_value("best", spot_id, -1.0))


static func _record(spot_id: String, weight: float) -> bool:
	if weight <= best(spot_id):
		return false
	var saved := ConfigFile.new()
	saved.load(BESTS)
	saved.set_value("best", spot_id, weight)
	saved.save(BESTS)
	return true


func _ready() -> void:
	_rod = FishingRod.new()
	_rod.build(pieces(), rod_size)
	_rod.visible = false
	add_child(_rod)
	_bobber = piece(pieces(), "bobber")
	_bobber.top_level = true
	_bobber.scale = Vector3.ONE * clampf(rod_size, 0.6, 1.0)
	_bobber.visible = false
	add_child(_bobber)
	# (the line: a thin ribbon turned to the camera, _draw_line)
	_line = MeshInstance3D.new()
	_line.top_level = true
	_line.mesh = ImmediateMesh.new()
	_line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var gut := StandardMaterial3D.new()
	gut.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	gut.cull_mode = BaseMaterial3D.CULL_DISABLED
	gut.albedo_color = Color(0.95, 0.95, 0.9)
	_line.material_override = gut
	add_child(_line)
	# The fish about the spot, as shadows in the water.
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(id)
	for i in shadows:
		var shadow := piece(pieces(), "fish_shadow")
		shadow.top_level = true
		add_child(shadow)
		shadow.global_position = _wander_spot(rng)
		shadow.scale = Vector3.ONE * rng.randf_range(0.8, 1.6) * clampf(rod_size, 0.5, 1.0)
		_shadows.append(shadow)
		_goals.append(_wander_spot(rng))
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	hud = FishingHud.new()
	hud.visible = false
	layer.add_child(hud)
	hud.pressed.connect(func(button: String) -> void:
		if button == "quit":
			quit())


## The water's height at (x, z).
func water_y(x: float, z: float) -> float:
	return float(water_at.call(x, z)) if water_at.is_valid() else water_level


func _wet(x: float, z: float) -> bool:
	return bool(is_water.call(x, z)) if is_water.is_valid() else true


func _say(text: String) -> void:
	if say.is_valid():
		say.call(text)


## Somewhere for a shadow to swim to: out over the water in front of the spot.
func _wander_spot(rng: RandomNumberGenerator) -> Vector3:
	var out := global_basis.z.normalized()
	var middle := global_position + out * (deep_from + wander.y)
	for attempt in 16:
		var p := middle + global_basis.x.normalized() * rng.randf_range(-wander.x, wander.x) + out * rng.randf_range(-wander.y, wander.y)
		if _wet(p.x, p.z) and Vector2(p.x - global_position.x, p.z - global_position.z).length() > deep_from:
			return Vector3(p.x, water_y(p.x, p.z) + 0.025, p.z)
	return Vector3(middle.x, water_y(middle.x, middle.z) + 0.025, middle.z)


## Starts fishing: he is put at the spot facing out, the rod in his hands.
func begin() -> void:
	if running or player == null:
		return
	running = true
	time = 0.0
	hud.visible = true
	hud.title = title
	var keys := main_actions.map(func(a: StringName) -> String: return _key_name(a))
	hud.set_buttons([["main", FishingButton.Symbol.CAST, keys[0] if not keys.is_empty() else ""], ["quit", FishingButton.Symbol.CROSS, _key_name(quit_actions[0]) if not quit_actions.is_empty() else ""]])
	Player.input_blocked = true
	if player._is_resting():
		player.wake()
	player.global_position = global_position + Vector3.UP * 0.05
	player.velocity = Vector3.ZERO
	player.facing_yaw = global_rotation.y
	if camera and camera.has_method(&"look_along"):
		camera.call(&"look_along", global_basis.z)
	if camera and camera.has_method(&"snap"):
		camera.call(&"snap")
	if player.carried and player.carried != _rod:
		player._let_go()
	_rod.visible = true
	_grip = HOLD_GRIP * hold_scale
	_point = HOLD_POINT
	_bend = 0.0
	_rod.reeling = false
	player.gun_handling = true
	player._take(_rod)
	player._carry_ease = 1.0
	_caught = 0
	_biggest = 0.0
	_held = true
	_set_stage(Stage.READY)
	started.emit()
	_say(title + "!")


## Puts the rod away.
func quit() -> void:
	if not running:
		return
	running = false
	hud.visible = false
	Player.input_blocked = false
	if player.carried == _rod:
		player._let_go()
	_rod.freeze = true
	_rod.collision_layer = 0
	_rod.collision_mask = 0
	_rod.visible = false
	_bobber.visible = false
	(_line.mesh as ImmediateMesh).clear_surfaces()
	if is_instance_valid(_landed):
		_landed.queue_free()
	if _taker >= 0:
		_flee()
	ended.emit()


func _key_name(action: StringName) -> String:
	if not InputMap.has_action(action):
		return ""
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			return OS.get_keycode_string((event as InputEventKey).physical_keycode)
	return ""


func _set_stage(next: Stage) -> void:
	stage = next
	_stage_time = 0.0
	var symbol := FishingButton.Symbol.CAST
	match next:
		Stage.WAITING, Stage.NIBBLE, Stage.BITE:
			symbol = FishingButton.Symbol.HOOK
		Stage.FIGHT:
			symbol = FishingButton.Symbol.REEL
	hud.show_symbol("main", symbol)


func _process(delta: float) -> void:
	_swim(delta)
	if not running:
		return
	if player._is_resting():
		player.wake()
	time += delta
	_play(delta)
	hud.lines = _panel()
	hud.queue_redraw()


func _action_held(list: Array[StringName]) -> bool:
	for action in list:
		if InputMap.has_action(action) and Input.is_action_pressed(action):
			return true
	return false


func _play(delta: float) -> void:
	_stage_time += delta
	for action in quit_actions:
		if InputMap.has_action(action) and Input.is_action_just_pressed(action):
			quit()
			return
	if should_stop.is_valid():
		var why := str(should_stop.call())
		if why != "":
			_say(why)
			quit()
			return
	# (the rod stays in his hands: anything that took it out of them gives it back)
	if player.carried != _rod:
		if player.carried:
			player._let_go()
		player.gun_handling = true
		player._take(_rod)
		player._carry_ease = 1.0
	var hold := hud.held("main") or _action_held(main_actions) or test_hold
	var press := hold and not _held
	var lift := _held and not hold
	_held = hold
	match stage:
		Stage.READY:
			_bobber.visible = false
			if press:
				_set_stage(Stage.CHARGING)
		Stage.CHARGING:
			_power = 0.5 - 0.5 * cos(_stage_time * 2.4)
			if lift:
				cast(_power)
		Stage.FLYING:
			var t := clampf(_stage_time / 0.8, 0.0, 1.0)
			_bobber.global_position = _from.lerp(_bob_at, t) + Vector3.UP * sin(PI * t) * 3.0 * rod_size
			if t >= 1.0:
				_set_stage(Stage.WAITING)
		Stage.WAITING:
			_bob(0.0)
			if press:
				_set_stage(Stage.READY)
			elif _taker < 0 and fmod(_stage_time, 1.0) < delta and randf() < 0.45:
				_call_a_fish()
			elif _taker >= 0 and _shadows[_taker].global_position.distance_to(_bob_at) < 0.6:
				_nibbles = randi_range(1, 3)
				_next_nibble = randf_range(0.4, 1.1)
				_set_stage(Stage.NIBBLE)
		Stage.NIBBLE:
			var since := _stage_time - (_next_nibble - 0.25)
			_bob(0.06 if since > 0.0 and since < 0.25 else 0.0)
			if press:
				_say("Too soon: it's off!")
				lost.emit("early")
				_flee()
				_set_stage(Stage.WAITING)
			elif _stage_time > _next_nibble:
				_nibbles -= 1
				if _nibbles <= 0:
					_set_stage(Stage.BITE)
				else:
					_next_nibble = _stage_time + randf_range(0.5, 1.2)
		Stage.BITE:
			_bob(0.3)
			if press:
				_hook()
			elif _stage_time > bite_time:
				_say("It got away with the bait.")
				lost.emit("bait")
				_flee()
				_set_stage(Stage.WAITING)
		Stage.FIGHT:
			_fight(hold, delta)
		Stage.LANDED:
			if _stage_time > 2.4:
				if is_instance_valid(_landed):
					_landed.queue_free()
				_set_stage(Stage.READY)
	_pose_rod(delta)


## Sends the bobber out: `power` 0..1 of the way along `cast_range`, as far as the water goes.
func cast(power: float) -> void:
	var out := global_basis.z.normalized()
	var reach := lerpf(cast_range.x, cast_range.y, clampf(power, 0.0, 1.0))
	var side := global_basis.x.normalized() * randf_range(-1.2, 1.2) * clampf(cast_range.y / 16.0, 0.2, 1.0)
	# (as far as asked if there is water there; else on out to the first water, or back in to the last)
	var wet := func(r: float) -> bool:
		var q := global_position + out * r + side
		return _wet(q.x, q.z)
	var reach_to := reach
	while not wet.call(reach_to) and reach_to < cast_range.y + 12.0:
		reach_to += 0.25
	if not wet.call(reach_to):
		reach_to = reach
		while not wet.call(reach_to) and reach_to > 0.5:
			reach_to -= 0.25
	var to := global_position + out * reach_to + side
	_from = _rod.tip()
	_bob_at = Vector3(to.x, water_y(to.x, to.z), to.z)
	_bobber.visible = true
	_set_stage(Stage.FLYING)


func _bob(dip: float) -> void:
	_bob_at.y = water_y(_bob_at.x, _bob_at.z)
	var wobble := sin(time * 3.1) * 0.012
	_bobber.global_position = _bob_at + Vector3.UP * (wobble - dip)


## One of the shadows near the bobber turns and comes to it.
func _call_a_fish() -> void:
	var best_one := -1
	for i in _shadows.size():
		var d := _shadows[i].global_position.distance_to(_bob_at)
		if d < 11.0 and (best_one < 0 or d < _shadows[best_one].global_position.distance_to(_bob_at)):
			best_one = i
	_taker = best_one


## For tests: a fish comes straight to the bobber and bites now.
func bite_now() -> void:
	if stage != Stage.WAITING and stage != Stage.NIBBLE:
		return
	if _taker < 0:
		_taker = 0
	_shadows[_taker].global_position = _bob_at
	_set_stage(Stage.BITE)


func _flee() -> void:
	if _taker >= 0:
		var away := (_shadows[_taker].global_position - global_position)
		away.y = 0.0
		_goals[_taker] = _shadows[_taker].global_position + away.normalized() * 6.0
		_taker = -1


## Struck as it bites: on the hook, a fish of one of the kinds, its weight, and the fight begins.
func _hook() -> void:
	var total := 0.0
	for kind: Array in kinds:
		total += float(kind[5])
	var pick := randf() * total
	_fish = kinds[0]
	for kind: Array in kinds:
		pick -= float(kind[5])
		if pick <= 0.0:
			_fish = kind
			break
	var share := pow(randf(), 1.8)
	_weight = lerpf(float(_fish[2]), float(_fish[3]), share)
	_pull = float(_fish[4]) * (0.65 + 0.35 * share)
	distance = Vector2(_bob_at.x - global_position.x, _bob_at.z - global_position.z).length()
	_start_distance = distance
	tension = 0.3
	_slack = 0.0
	_surging = false
	_surge_time = randf_range(0.6, 1.4)
	_say("Hooked!")
	_set_stage(Stage.FIGHT)


func _fight(hold: bool, delta: float) -> void:
	_surge_time -= delta
	if _surge_time <= 0.0:
		_surging = not _surging and randf() < 0.75
		_surge_time = randf_range(0.6, 1.4) if _surging else randf_range(1.0, 2.4)
	var force := _pull * (1.7 if _surging else 0.35)
	# (how quickly it is brought in, for the spot's size: a pond's fish come in over a few metres)
	var pace := clampf(cast_range.y / 16.0, 0.35, 1.0)
	if hold:
		tension += (0.22 + force * 0.85) * delta
		distance -= (2.4 - _pull * 0.9) * (0.35 if _surging else 1.0) * delta * pace
	else:
		tension -= 0.6 * delta
		distance += force * 1.6 * delta * pace
	tension = maxf(tension, 0.0)
	_slack = _slack + delta if tension < 0.06 else 0.0
	# The fish under the water where the line goes in, swinging side to side as it fights.
	var out := global_basis.z.normalized()
	var side := global_basis.x.normalized() * sin(time * (3.0 if _surging else 1.4)) * minf(distance * 0.15, 1.6)
	var at := global_position + out * distance + side
	at.y = water_y(at.x, at.z)
	_bob_at = at
	_bobber.global_position = at + Vector3.DOWN * (0.12 if _surging else 0.03)
	if _taker >= 0:
		_shadows[_taker].global_position = Vector3(at.x, at.y + 0.025, at.z)
	if tension >= 1.0:
		_say("The line snapped!")
		_lost("snapped")
	elif _slack > slack_time:
		_say("It threw the hook.")
		_lost("threw")
	elif distance > _start_distance + 9.0 * pace:
		_say("It ran off with the line.")
		_lost("ran")
	elif distance <= 1.6 * pace:
		_land()


func _lost(why: String) -> void:
	lost.emit(why)
	_flee()
	_bobber.visible = false
	_set_stage(Stage.READY)


## Landed: held up to see, weighed; the biggest kept.
func _land() -> void:
	_caught += 1
	_bobber.visible = false
	if _taker >= 0:
		# (that shadow swims in again from further out, as another fish)
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		_shadows[_taker].global_position = _wander_spot(rng)
		_taker = -1
	_landed = piece(pieces(), "fish_" + str(_fish[0]))
	_landed.top_level = true
	add_child(_landed)
	var grown := clampf(pow(_weight / float(_fish[3]), 0.33) * 1.25, 0.6, 1.4) * clampf(rod_size, 0.5, 1.0)
	_landed.scale = Vector3.ONE * grown
	_biggest = maxf(_biggest, _weight)
	var record := _record(id, _weight)
	_say("%s, %.1f kg!%s" % [_fish[1], _weight, "  A record!" if record else ""])
	caught.emit(str(_fish[1]), _weight, record)
	_set_stage(Stage.LANDED)


## The moves with the rod (FishingRod.held_at): his right hand's place from his right shoulder and the way the rod
## points, in his own frame (+z ahead, +x his left, up), at the boy's reach (times `hold_scale`). Held ready: the
## butt at his hip, the rod up and out; back over his shoulder gathering a cast; flicked forward; lowered, waiting;
## lifted sharply to strike; up and leaning back in a fight; high, holding the catch up.
const HOLD_GRIP := Vector3(0.08, -0.36, 0.24)
const HOLD_POINT := Vector3(0.0, 0.55, 1.0)
const BACK_GRIP := Vector3(0.02, 0.02, 0.06)
const BACK_POINT := Vector3(-0.05, 1.0, -0.5)
const FLICK_GRIP := Vector3(0.06, -0.16, 0.36)
const FLICK_POINT := Vector3(0.0, 0.1, 1.0)
const WAIT_GRIP := Vector3(0.08, -0.3, 0.3)
const WAIT_POINT := Vector3(0.0, 0.2, 1.0)
const STRIKE_GRIP := Vector3(0.06, -0.04, 0.2)
const STRIKE_POINT := Vector3(0.0, 1.6, 0.45)
const FIGHT_GRIP := Vector3(0.07, -0.24, 0.26)
const FIGHT_POINT := Vector3(0.0, 0.95, 0.75)
const LAND_GRIP := Vector3(0.05, 0.08, 0.3)
const LAND_POINT := Vector3(0.0, 1.5, 0.35)
## How long the flick forward and the strike take (s).
const FLICK := 0.22
const STRIKE := 0.3


## Each move's hold, eased into; the rod's bend; the reel turning while he reels; the line.
func _pose_rod(delta: float) -> void:
	var grip := HOLD_GRIP
	var point := HOLD_POINT
	var bend := 0.0
	var rate := 8.0
	var t := _stage_time
	_rod.reeling = false
	match stage:
		Stage.CHARGING:
			var k := smoothstep(0.0, 0.35, t)
			grip = HOLD_GRIP.lerp(BACK_GRIP, k)
			point = HOLD_POINT.normalized().slerp(BACK_POINT.normalized(), k) + Vector3.UP * 0.12 * _power
			bend = 0.12 * k
			rate = 14.0
		Stage.FLYING:
			if t < FLICK:
				var f := ease(t / FLICK, 0.4)
				grip = BACK_GRIP.lerp(FLICK_GRIP, f)
				point = BACK_POINT.normalized().slerp(FLICK_POINT.normalized(), f)
				bend = 0.45 * sin(PI * minf(t / FLICK, 1.0))
				rate = 40.0
			else:
				grip = FLICK_GRIP.lerp(WAIT_GRIP, smoothstep(FLICK, 0.8, t))
				point = FLICK_POINT.lerp(WAIT_POINT, smoothstep(FLICK, 0.8, t))
				rate = 12.0
		Stage.WAITING, Stage.NIBBLE, Stage.BITE:
			grip = WAIT_GRIP
			point = WAIT_POINT + Vector3(sin(time * 1.1) * 0.03, sin(time * 0.7) * 0.03, 0.0)
			bend = 0.05
			if stage == Stage.NIBBLE:
				var since := t - (_next_nibble - 0.25)
				if since > 0.0 and since < 0.25:
					point.y -= 0.08
					bend = 0.15
			elif stage == Stage.BITE:
				point.y -= 0.12 + sin(time * 30.0) * 0.03
				bend = 0.3
		Stage.FIGHT:
			if t < STRIKE:
				grip = STRIKE_GRIP
				point = STRIKE_POINT
				bend = 0.6
				rate = 30.0
			else:
				grip = FIGHT_GRIP
				point = FIGHT_POINT
				bend = 0.2 + tension * 0.8
				if _surging:
					# (it bucks as the fish runs)
					point += Vector3(sin(time * 13.0) * 0.1, -0.15 + sin(time * 9.0) * 0.08, 0.0)
					bend += 0.15
				rate = 12.0
			_rod.reeling = _held
			if _held:
				_rod.crank += delta * 11.0
		Stage.LANDED:
			grip = LAND_GRIP
			point = land_point
			bend = 0.25 + clampf(_weight / 10.0, 0.0, 1.0) * 0.4
	var ease_by := 1.0 - exp(-rate * delta)
	_grip = _grip.lerp(grip * hold_scale, ease_by)
	_point = _point.normalized().slerp(point.normalized(), ease_by)
	_bend = lerpf(_bend, bend, 1.0 - exp(-10.0 * delta))
	_rod.grip = _grip
	_rod.point = _point
	_rod.bend = _bend
	# The line from the tip: to the bobber, or a short drop holding the catch.
	var tip := _rod.tip()
	var end := _bobber.global_position if _bobber.visible else tip + Vector3.DOWN * 0.5 * rod_size
	if stage == Stage.LANDED and is_instance_valid(_landed):
		end = tip + Vector3.DOWN * 0.6 * rod_size
		_landed.global_transform = Transform3D(Basis(Vector3.RIGHT, -PI * 0.5).rotated(Vector3.UP, global_rotation.y + PI).scaled(_landed.scale), end + Vector3.DOWN * 0.25 * _landed.scale.x)
	var sag := 0.0
	if stage == Stage.FIGHT:
		sag = 0.6 * rod_size * clampf(1.0 - tension * 1.6, 0.0, 1.0)
	elif stage != Stage.LANDED and _bobber.visible:
		sag = 0.04 * tip.distance_to(end)
	_draw_line(tip, end, sag)


## The line: a thin ribbon from `from` to `to` hanging `sag` in the middle, turned to the camera and kept about a
## pixel and a half wide however far off it is.
func _draw_line(from: Vector3, to: Vector3, sag: float) -> void:
	var mesh := _line.mesh as ImmediateMesh
	mesh.clear_surfaces()
	var eye_cam := get_viewport().get_camera_3d()
	if eye_cam == null:
		return
	var eye := eye_cam.global_position
	var count := 18
	var points: Array[Vector3] = []
	for k in count + 1:
		var s := float(k) / count
		points.append(from.lerp(to, s) + Vector3.DOWN * 4.0 * s * (1.0 - s) * sag)
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for k in points.size():
		var p := points[k]
		var along := (points[mini(k + 1, count)] - points[maxi(k - 1, 0)]).normalized()
		var side := along.cross(eye - p).normalized()
		var half := maxf(0.003, p.distance_to(eye) * 0.0016)
		mesh.surface_add_vertex(p - side * half)
		mesh.surface_add_vertex(p + side * half)
	mesh.surface_end()


## The shadows wander about (and the one coming to the bobber swims to it).
func _swim(delta: float) -> void:
	for i in _shadows.size():
		var shadow := _shadows[i]
		if running and stage == Stage.FIGHT and i == _taker:
			continue
		var goal := _goals[i]
		if running and i == _taker and stage in [Stage.WAITING, Stage.NIBBLE, Stage.BITE]:
			goal = _bob_at + (shadow.global_position - _bob_at).normalized() * 0.35
		var to := goal - shadow.global_position
		to.y = 0.0
		var speed := (1.3 if i == _taker else 0.7) * clampf(rod_size, 0.5, 1.0)
		if to.length() < 0.2:
			if i != _taker:
				var rng := RandomNumberGenerator.new()
				rng.seed = hash(i * 977 + int(time * 10.0) + Time.get_ticks_msec())
				_goals[i] = _wander_spot(rng)
			continue
		shadow.global_position += to.normalized() * minf(speed * delta, to.length())
		shadow.global_position.y = water_y(shadow.global_position.x, shadow.global_position.z) + 0.025
		shadow.global_rotation.y = lerp_angle(shadow.global_rotation.y, atan2(to.x, to.z), 1.0 - exp(-4.0 * delta))


func _panel() -> Array:
	var biggest := "Biggest today: %.1f kg" % _biggest if _biggest > 0.0 else "Nothing yet"
	var kept := best(id)
	var line := ""
	match stage:
		Stage.READY:
			line = "Hold to cast"
		Stage.CHARGING:
			line = "Cast  " + _bar(_power)
		Stage.FLYING, Stage.WAITING:
			line = "Waiting for a bite..."
		Stage.NIBBLE:
			line = "A nibble... wait for it"
		Stage.BITE:
			line = "It's biting! Strike!"
		Stage.FIGHT:
			line = "Line  " + _bar(tension) + "   %.0f m" % distance
		Stage.LANDED:
			line = "%s, %.1f kg" % [_fish[1], _weight]
	return [line, "Caught %d   %s%s" % [_caught, biggest, ("   Record %.1f" % kept) if kept >= 0.0 else ""]]


func _bar(share: float) -> String:
	var full := clampi(roundi(share * 14.0), 0, 14)
	return "[" + "|".repeat(full) + ".".repeat(14 - full) + "]" + (" !" if share > 0.8 else "")
