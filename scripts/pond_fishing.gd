class_name PondFishing
extends Node
## Fishing in the grove's pond (the user, 2026-11-02: "there should be a pond in the grove and a fishing minigame (we
## have assets for that)"): GameCommon's godot/fishing (FishingSpot, from Gloaming's) on the pond's bank. Walking up
## to the spot, a round button comes up on screen (F, or LB on a pad, does the same); he takes up a rod sized for him
## and fishes until the cross (or duck) puts it away. The spot is the `fishing_spot` marker (facing `fishing_water`,
## else the pond's middle), else the pond's west bank facing east over it (Claude's pick). The pond's fish are
## FishingSpot.POND_FISH: koi, carp, bluegill, catfish and a rare golden koi (Claude's picks).
##
##   PondFishing.place(world)     # once the pool and the HUD are in

## How near the spot he must be for the button (m).
const NEAR := 1.6

var world: World
var spot: FishingSpot
var _prompt: FishingButton
var _layer: CanvasLayer
var _grounded := false


static func place(world: World) -> PondFishing:
	var pool: Pool = null
	for child in world.get_children():
		if child is Pool:
			pool = child
			break
	if pool == null:
		return null
	var fishing := PondFishing.new()
	fishing.name = "PondFishing"
	fishing.world = world
	world.add_child(fishing)
	fishing._make(pool)
	return fishing


func _make(pool: Pool) -> void:
	var middle := pool.global_position
	var water: Vector3 = (world.markers["fishing_water"] as Transform3D).origin if world.markers.has("fishing_water") else middle
	var bank := middle + Vector3(-(pool.size.x * 0.5 + 0.5), 0.25, 0.0)
	if world.markers.has("fishing_spot"):
		bank = (world.markers["fishing_spot"] as Transform3D).origin
	var out := Vector3(water.x - bank.x, 0.0, water.z - bank.z).normalized()
	spot = FishingSpot.new()
	spot.id = "grove_pond"
	spot.title = "Pond"
	spot.kinds = FishingSpot.POND_FISH
	# (a small pond, about 5.6 by 4.2 m: short casts, the fish wandering its middle)
	spot.cast_range = Vector2(1.5, 5.0)
	spot.deep_from = 1.2
	spot.wander = Vector2(1.6, 1.8)
	spot.shadows = 5
	# (his short arms and a rod his size: the raccoon is about 0.6 m tall, the rod about 1 m)
	spot.hold_scale = 0.55
	spot.rod_size = 0.32
	# (the catch held out ahead of him, about his eyes, not up over his head)
	spot.land_point = Vector3(0.0, 0.55, 1.0)
	spot.main_actions = [&"fish", &"jump"]
	spot.quit_actions = [&"duck"]
	spot.water_level = pool.surface_y()
	var half := Vector2(pool.size.x, pool.size.z) * 0.5
	spot.is_water = func(x: float, z: float) -> bool:
		return Vector2((x - middle.x) / half.x, (z - middle.z) / half.y).length() < 0.85
	spot.player = world.player
	spot.camera = world.camera
	spot.say = func(text: String) -> void:
		if world.hud:
			world.hud.say(text)
	world.add_child(spot)
	spot.global_transform = Transform3D(Basis(Vector3.UP, atan2(out.x, out.z)), bank)
	if not InputMap.has_action(&"fish"):
		InputMap.add_action(&"fish")
		var key := InputEventKey.new()
		key.physical_keycode = KEY_F
		InputMap.action_add_event(&"fish", key)
		var pad := InputEventJoypadButton.new()
		pad.button_index = JOY_BUTTON_LEFT_SHOULDER
		InputMap.action_add_event(&"fish", pad)
	# The button that comes up by the spot
	_layer = CanvasLayer.new()
	_layer.layer = 4
	add_child(_layer)
	_prompt = FishingButton.new()
	_prompt.symbol = FishingButton.Symbol.CAST
	_prompt.key = "F"
	_prompt.visible = false
	_prompt.pressed.connect(start)
	_layer.add_child(_prompt)


## Whether he is fishing in `world` now.
static func busy(world: World) -> bool:
	var fishing := world.get_node_or_null(^"PondFishing") as PondFishing
	return fishing != null and fishing.spot != null and fishing.spot.running


## He takes up the rod.
func start() -> void:
	if spot and not spot.running:
		_prompt.visible = false
		spot.begin()


## Whether he is where the button comes up.
func near() -> bool:
	var player := world.player
	if spot == null or spot.running or BirdPlayer.active(world) or not player.visible or not player.is_on_floor():
		return false
	var d := player.global_position - spot.global_position
	return Vector2(d.x, d.z).length() < NEAR and absf(d.y) < 1.0


func _physics_process(_delta: float) -> void:
	if spot == null:
		return
	# (the bank's height, once the physics has the ground)
	if not _grounded:
		_grounded = true
		var at := spot.global_position
		var hit := spot.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(at + Vector3.UP * 3.0, at + Vector3.DOWN * 3.0, 1))
		if not hit.is_empty():
			spot.global_position.y = (hit.position as Vector3).y
	var show := near()
	if show and not _prompt.visible:
		var seen := _prompt.get_viewport_rect().size
		var r := minf(seen.x, seen.y) / 720.0 * 62.0
		_prompt.size = Vector2(r, r) * 2.0
		_prompt.position = Vector2(seen.x * 0.5 - r, seen.y - r * 2.0 - seen.y * 0.16)
	_prompt.visible = show
	if show and Input.is_action_just_pressed(&"fish"):
		start()
