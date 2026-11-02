class_name World
extends Node3D
## A world: its model (built in Blender, models/<name>.glb), and what the game puts
## in it at the model's markers (see tools/build_world1.py): the raccoon, the camera,
## Crumbs, Bottlecaps, cats, the race, the trampoline, the trellis and the pond.
## Keeps the score and his hearts.

signal crumbs_changed(count: int, total: int)
signal caps_changed(count: int, total: int)
signal hearts_changed(count: int)
signal said(text: String)

const WORLD_SHADER := preload("res://shaders/world.gdshader")
const MAX_HEARTS := 3
const CAP_NAMES := {
	"roof": "Up the chimney",
	"glide": "The billboard",
	"cats": "Cat scrap",
	"race": "Alley dash",
	"hidden": "Under the porch",
}

@export var model: PackedScene = preload("res://models/world1.glb")

var player: Player
var camera: FollowCamera
var hud: Hud
var race: Race
var crumbs := 0
var crumbs_total := 0
var caps: Array[String] = []
var hearts := MAX_HEARTS
var markers := {}

var _hurt_rest := 0.0
var _cats_left := 0
var _checkpoints: Array[Vector3] = []


func _ready() -> void:
	add_to_group(&"game")
	_environment()
	var level := model.instantiate()
	add_child(level)
	_dress(level)
	for node in level.find_children("*", "Node3D", true, false):
		if not node is MeshInstance3D:
			markers[String(node.name)] = (node as Node3D).global_transform

	player = (load("res://raccoon.tscn") as PackedScene).instantiate()
	add_child(player)
	var spawn: Transform3D = markers.get("spawn", Transform3D.IDENTITY)
	player.global_position = spawn.origin
	player.facing_yaw = PI
	player.set_spawn(spawn.origin)
	player.respawned.connect(_on_respawned)
	camera = FollowCamera.new()
	camera.target = player
	camera.mode = FollowCamera.Mode.ORBIT
	camera.distance = 5.5
	add_child(camera)

	_place_things()
	add_child(N64Filter.new())
	hud = Hud.new()
	hud.world = self
	add_child(hud)
	var touch := TouchControls.new()
	# (he sprints only for the sprint button, not for a stick pushed right over: the user, 2026-11-01)
	touch.sprint_rim = 100.0
	touch.set_anchors_preset(Control.PRESET_FULL_RECT)
	var touch_layer := CanvasLayer.new()
	touch_layer.layer = 3
	touch_layer.add_child(touch)
	add_child(touch_layer)
	crumbs_changed.emit(crumbs, crumbs_total)
	caps_changed.emit(caps.size(), CAP_NAMES.size())
	hearts_changed.emit(hearts)


func _environment() -> void:
	var sun := DirectionalLight3D.new()
	# Low evening sun from over the alley
	sun.rotation_degrees = Vector3(-28.0, 60.0, 0.0)
	sun.light_color = Color(1.0, 0.78, 0.58)
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 40.0
	add_child(sun)
	var sky := ProceduralSkyMaterial.new()
	sky.sky_top_color = Color(0.22, 0.28, 0.52)
	sky.sky_horizon_color = Color(0.98, 0.62, 0.45)
	sky.ground_horizon_color = Color(0.6, 0.45, 0.4)
	sky.ground_bottom_color = Color(0.2, 0.18, 0.2)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = Sky.new()
	environment.sky.sky_material = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.55, 0.52, 0.7)
	environment.ambient_light_energy = 0.75
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.72, 0.62, 0.66)
	environment.fog_density = 0.0035
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	add_child(world_environment)


## The world's own materials made N64 ones, and every solid thing given a collision shape.
func _dress(level: Node) -> void:
	var made := {}
	for mesh: MeshInstance3D in level.find_children("*", "MeshInstance3D", true, false):
		for k in mesh.mesh.get_surface_count():
			var original := mesh.mesh.surface_get_material(k)
			var key := original.resource_name if original else "plain"
			if not made.has(key):
				var material := ShaderMaterial.new()
				material.shader = WORLD_SHADER
				var colour := (original as BaseMaterial3D).albedo_color if original is BaseMaterial3D else Color.WHITE
				material.set_shader_parameter(&"albedo", colour)
				material.set_shader_parameter(&"emission", 0.9 if key == "window" else 0.0)
				made[key] = material
			mesh.set_surface_override_material(k, made[key])
		if not String(mesh.name).begins_with("nocol_"):
			mesh.create_trimesh_collision()
			# (solid from both sides: an open sheet such as the lawn has no outside to be sure of)
			for shape: CollisionShape3D in mesh.find_children("*", "CollisionShape3D", true, false):
				(shape.shape as ConcavePolygonShape3D).backface_collision = true


func _place_things() -> void:
	for name: String in markers:
		var at: Vector3 = markers[name].origin
		if name.begins_with("crumb_"):
			var crumb := Pickup.make(Pickup.Kind.CRUMB, at)
			crumb.taken.connect(_on_crumb)
			add_child(crumb)
			crumbs_total += 1
		elif name.begins_with("cap_") and name != "cap_cats" and name != "cap_race":
			_add_cap(name.substr(4), at)
		elif name.begins_with("cat_"):
			var cat := YardCat.new()
			cat.position = at
			cat.target = player
			cat.beaten.connect(_on_cat_beaten)
			add_child(cat)
			_cats_left += 1
		elif name.begins_with("check_"):
			_checkpoints.append(at)
	if markers.has("trampoline"):
		var bed := Trampoline.new()
		bed.position = markers["trampoline"].origin
		add_child(bed)
	if markers.has("ladder"):
		var ladder := Ladder.new()
		ladder.height = 1.8
		ladder.transform = markers["ladder"]
		add_child(ladder)
	if markers.has("pond"):
		var pool := Pool.new()
		pool.size = Vector3(8.8, 1.7, 7.2)
		pool.position = markers["pond"].origin
		add_child(pool)
	if markers.has("race_start"):
		race = Race.new()
		race.position = markers["race_start"].origin
		var k := 0
		while markers.has("race_%d" % k):
			race.route.append(markers["race_%d" % k].origin)
			k += 1
		race.started.connect(func() -> void: said.emit("Take every glowing crumb before time runs out!"))
		race.lost.connect(func() -> void: said.emit("Too slow! Try the stopwatch again."))
		race.won.connect(func() -> void: _reveal("race"))
		add_child(race)


func _add_cap(called: String, at: Vector3) -> void:
	if called in caps:
		return
	var cap := Pickup.make(Pickup.Kind.CAP, at, called)
	cap.taken.connect(_on_cap)
	add_child(cap)


## A Bottlecap that is won appears at its marker.
func _reveal(called: String) -> void:
	var name := "cap_" + called
	if markers.has(name):
		_add_cap(called, markers[name].origin)
		said.emit("A Bottlecap has appeared!")


func _on_crumb(_pickup: Pickup) -> void:
	crumbs += 1
	crumbs_changed.emit(crumbs, crumbs_total)
	if crumbs == crumbs_total:
		said.emit("Every crumb in the yard!")


func _on_cap(pickup: Pickup) -> void:
	caps.append(pickup.tag)
	caps_changed.emit(caps.size(), CAP_NAMES.size())
	said.emit("Bottlecap! %s" % CAP_NAMES.get(pickup.tag, ""))
	hearts = MAX_HEARTS
	hearts_changed.emit(hearts)


func _on_cat_beaten(_cat: YardCat) -> void:
	_cats_left -= 1
	if _cats_left <= 0:
		_reveal("cats")
	else:
		said.emit("%d cat%s left" % [_cats_left, "" if _cats_left == 1 else "s"])


func _process(delta: float) -> void:
	_hurt_rest = maxf(_hurt_rest - delta, 0.0)
	# He starts again from the nearest checkpoint he has passed.
	for at in _checkpoints:
		if player.is_on_floor() and player.global_position.distance_to(at) < 2.0:
			player.set_spawn(at)
	# (blinking while he cannot be hurt again)
	var rig := player.get_node(^"Rig") as Node3D
	rig.visible = _hurt_rest <= 0.0 or fmod(_hurt_rest, 0.16) < 0.1


## A cat's pounce, or anything else that hurts: a heart gone, and knocked back.
func hurt(from: Vector3) -> void:
	if _hurt_rest > 0.0:
		return
	_hurt_rest = 1.4
	hearts -= 1
	hearts_changed.emit(hearts)
	var away := player.global_position - from
	away.y = 0.0
	player.velocity = away.normalized() * 5.0 + Vector3.UP * 4.5
	if hearts <= 0:
		said.emit("Ouch! Back to the last checkpoint.")
		player.respawn()


func _on_respawned() -> void:
	if hearts <= 0:
		hearts = MAX_HEARTS
	else:
		# (a fall out of the world)
		hearts = maxi(hearts - 1, 1)
	hearts_changed.emit(hearts)
