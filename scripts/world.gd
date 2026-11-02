class_name World
extends Node3D
## A world: its model (built in Blender, models/<name>.glb), and what the game puts
## in it at the model's markers (see tools/build_world1.py): the raccoon, the camera, Crumbs,
## Bottlecaps, cats, trash cans, wires, the race, the trampoline, trellises and the pool. Paints the
## model with the Banjo-style textures (TEXTURES).
## Keeps the score and his hearts.

signal crumbs_changed(count: int, total: int)
signal caps_changed(count: int, total: int)
signal hearts_changed(count: int)
signal said(text: String)

const WORLD_SHADER := preload("res://shaders/world.gdshader")
const MAX_HEARTS := 3
## Below this nothing is on the world any more (the hill's foot is at -34 m: tools/build_town.py FOOT_Y): he starts
## again, a raccoon of the band or the town is dead.
const KILL_Y := -55.0
const CAP_NAMES := {
	"roof": "Up the chimney",
	"glide": "The billboard",
	"cats": "Cat scrap",
	"race": "Alley dash",
	"hidden": "Under the porch",
}

## The world model's materials that are painted: material -> [texture in textures/, metres to a repeat, tint].
## The rest keep their own colour. (The user, 2026-11-01: "we'll need banjo kazooie style textures".)
const TEXTURES := {
	"grass": ["grass", 2.0, Color.WHITE], "dirt": ["dirt", 2.0, Color.WHITE],
	"asphalt": ["asphalt", 3.0, Color.WHITE], "concrete": ["concrete", 2.0, Color.WHITE],
	"brick": ["brick", 1.4, Color.WHITE], "stone": ["stone", 1.5, Color.WHITE],
	"siding": ["siding", 1.6, Color.WHITE], "siding2": ["siding", 1.6, Color(1.6, 1.25, 0.62)],
	"siding3": ["siding", 1.6, Color(1.0, 1.18, 0.74)],
	"roof": ["shingles", 1.4, Color.WHITE], "roof2": ["shingles", 1.4, Color(0.62, 0.72, 1.1)],
	"wood": ["planks", 1.2, Color.WHITE], "darkwood": ["planks", 1.2, Color(0.62, 0.6, 0.6)],
	"fence": ["fence", 1.4, Color.WHITE], "pole": ["concrete", 1.0, Color(1.25, 1.25, 1.22)],
	"metal": ["metal", 1.0, Color.WHITE], "bin": ["metal", 1.0, Color(0.55, 0.85, 0.62)],
	# (the town after Pom Poko and Whisper of the Heart: block retaining walls, tiled roofs, plaster, thatch)
	"blockwall": ["blockwall", 2.0, Color.WHITE], "kawara": ["tiles", 1.6, Color.WHITE],
	"kawara2": ["tiles", 1.6, Color(1.3, 0.72, 0.52)], "kawara3": ["tiles", 1.6, Color(0.66, 0.66, 0.72)],
	"plaster": ["plaster", 2.0, Color.WHITE], "plaster2": ["plaster", 2.0, Color(0.92, 0.94, 0.96)],
	"shopred": ["plaster", 2.0, Color(0.82, 0.44, 0.3)], "thatch": ["thatch", 1.6, Color.WHITE],
}

@export var model: PackedScene = preload("res://models/world1.glb")

var player: Player
var camera: FollowCamera
var hud: Hud
## The lost kits (LostKits).
var lost_kits: LostKits
## The hill's zones (Zones).
var zones: Zones
## The wind over the hill (GameCommon WindField).
var wind: WindField
var race: Race
var crumbs := 0
var crumbs_total := 0
var caps: Array[String] = []
var hearts := MAX_HEARTS
var markers := {}

var _hurt_rest := 0.0
var _cats_left := 0
var _checkpoints: Array[Vector3] = []
var _sun: DirectionalLight3D


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
	player.kill_height = KILL_Y
	var spawn: Transform3D = markers.get("spawn", Transform3D.IDENTITY)
	player.global_position = spawn.origin
	# (the way the spawn marker is turned: down the hill)
	player.facing_yaw = spawn.basis.get_euler().y
	player.set_spawn(spawn.origin)
	player.respawned.connect(_on_respawned)
	_controls()
	camera = FollowCamera.new()
	camera.target = player
	camera.mode = FollowCamera.Mode.ORBIT
	# (closer in: the user, 2026-11-02, "the camera should be zoomed in more")
	camera.distance = 4.0
	add_child(camera)
	# (from behind him, looking the way he faces: down the hill from the grove)
	camera.look_along(Vector3(sin(player.facing_yaw), 0.0, cos(player.facing_yaw)))

	_place_things()
	# The town's hazards (birds, the fox, people, cars), and his band of raccoons
	Hazards.place(self, markers, player)
	# (the owl: on a pole far from the grove, swooping at him; a placeholder role, Claude's pick)
	HazardOwl.place(self, markers, player)
	HazardDog.place(self, markers, player)
	# Daughter Of The Wind's clouds round the sky (GameCommon puff-clouds; the user: "the clouds should be like
	# daughter of the wind")
	PuffClouds.add_to(self, _sun)
	Squad.place(self, player)
	Villagers.place(self, markers, player)
	# The kits lost about the hill, to find and send home to the grove
	lost_kits = LostKits.place(self, markers, get_node(^"Villagers") as Villagers, player)
	# The hill's four sides, each with its own food and kits to find
	zones = Zones.place(self)
	_grow_lawn()
	add_child(N64Filter.new())
	hud = Hud.new()
	hud.world = self
	add_child(hud)
	var touch := TouchControls.new()
	# (he sprints only for the sprint button, not for a stick pushed right over: the user, 2026-11-01)
	touch.sprint_rim = 100.0  # (and a full push of the stick sprints by itself: Player.auto_sprint)
	touch.set_anchors_preset(Control.PRESET_FULL_RECT)
	var touch_layer := CanvasLayer.new()
	touch_layer.layer = 3
	touch_layer.add_child(touch)
	add_child(touch_layer)
	crumbs_changed.emit(crumbs, crumbs_total)
	caps_changed.emit(caps.size(), CAP_NAMES.size())
	hearts_changed.emit(hearts)


## His controls, over what the Player sets up: no sprint (he runs on all fours anyway; the user, 2026-11-01:
## "remove the sprint button"), and on a gamepad X to duck and slide, B for the tail (the user, 2026-11-01).
func _controls() -> void:
	if InputMap.has_action(&"sprint"):
		InputMap.action_erase_events(&"sprint")
	for action: StringName in [&"duck", &"tail"]:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for event in InputMap.action_get_events(action):
			if event is InputEventJoypadButton:
				InputMap.action_erase_event(action, event)
	var duck := InputEventJoypadButton.new()
	duck.button_index = JOY_BUTTON_X
	InputMap.action_add_event(&"duck", duck)
	# (and on Y: the user, 2026-11-01, "y remains duck"; scurry is the left trigger, scripts/scurry.gd)
	var duck_y := InputEventJoypadButton.new()
	duck_y.button_index = JOY_BUTTON_Y
	InputMap.action_add_event(&"duck", duck_y)
	var tail := InputEventJoypadButton.new()
	tail.button_index = JOY_BUTTON_B
	InputMap.action_add_event(&"tail", tail)


func _environment() -> void:
	var sun := DirectionalLight3D.new()
	_sun = sun
	# A summer afternoon after the films' skies (Claude's pick, with the user's "why is the sky gray", 2026-11-02):
	# a high warm sun, a clear blue sky, a pale warm horizon, a thin blue haze over the town below
	sun.rotation_degrees = Vector3(-48.0, 50.0, 0.0)
	sun.light_color = Color(1.0, 0.96, 0.86)
	sun.light_energy = 1.15
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 45.0
	add_child(sun)
	var sky := ProceduralSkyMaterial.new()
	sky.sky_top_color = Color(0.16, 0.42, 0.82)
	sky.sky_horizon_color = Color(0.7, 0.84, 0.94)
	sky.sky_curve = 0.12
	sky.ground_horizon_color = Color(0.7, 0.84, 0.94)
	sky.ground_bottom_color = Color(0.36, 0.5, 0.4)
	sky.sun_angle_max = 20.0
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = Sky.new()
	environment.sky.sky_material = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.62, 0.72, 0.86)
	environment.ambient_light_energy = 0.8
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.7, 0.84, 0.94)
	environment.fog_density = 0.0022
	environment.fog_sky_affect = 0.0
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
			if not made.has(key) and key.begins_with("sky_"):
				# (the far hills and the volcano: their colours already hazed, so unshaded and out of the fog)
				var far := StandardMaterial3D.new()
				far.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				far.albedo_color = (original as BaseMaterial3D).albedo_color if original is BaseMaterial3D else Color.WHITE
				far.vertex_color_use_as_albedo = true
				far.disable_fog = true
				made[key] = far
			if not made.has(key):
				var material := ShaderMaterial.new()
				material.shader = WORLD_SHADER
				var colour := (original as BaseMaterial3D).albedo_color if original is BaseMaterial3D else Color.WHITE
				if TEXTURES.has(key):
					var paint: Array = TEXTURES[key]
					colour = paint[2]
					material.set_shader_parameter(&"tex", load("res://textures/%s.png" % paint[0]))
					material.set_shader_parameter(&"textured", true)
					material.set_shader_parameter(&"tile", paint[1])
				material.set_shader_parameter(&"albedo", colour)
				material.set_shader_parameter(&"emission", 0.9 if key == "window" else 0.0)
				made[key] = material
			mesh.set_surface_override_material(k, made[key])
		# (anything named `hidden_` is solid but not seen: the wall round the brink that keeps him in)
		if String(mesh.name).begins_with("hidden_") or String(mesh.name).ends_with("_hidden"):
			mesh.visible = false
		# (anything named `climb_` he can scurry up: Scurry)
		if String(mesh.name).begins_with("climb_"):
			mesh.add_to_group(&"climbable")
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
			var cat := YardCat.make()
			cat.position = at
			cat.target = player
			cat.beaten.connect(_on_cat_beaten)
			cat.add_to_group(&"interest")
			add_child(cat)
			_cats_left += 1
		elif name.begins_with("treep_"):
			# (treep_<n>_<seed>_<size%>_<kind>: a plain tree, no limbs to stand on; the user, 2026-11-02, "not all
			# trees need a bunch of climbable branches")
			var parts := name.split("_")
			var tree := TreeGen.preset("Fir" if parts[4] == "cedar" else "Oak")
			tree.seed = int(parts[2])
			tree.bark_style = TreeGen.Bark.OAK
			tree.joined = true
			var body := tree.body()
			# (a plain tree has no collision of its own: its trunk is given a solid to bump into and scurry up, up
			# into the crown, where he hops off onto its top; the user, 2026-11-02, "pine trees need collision and
			# should be climbable")
			var trunk := CollisionShape3D.new()
			var solid := CylinderShape3D.new()
			solid.radius = tree.trunk_radius * 0.9
			solid.height = tree.height * (0.8 if parts[4] == "cedar" else 0.55)
			trunk.shape = solid
			trunk.position.y = solid.height / 2.0
			body.add_child(trunk)
			# (and at its top a flare out into the crown, as on the drainpipes: climbing, it eases him out round
			# the trunk, and over the top he lands on its broad top)
			var flare := PackedVector3Array()
			for k in 10:
				var turn := TAU * k / 10.0
				flare.append(Vector3(cos(turn), 0.0, sin(turn)) * solid.radius + Vector3.UP * (solid.height - 1.2))
				flare.append(Vector3(cos(turn), 0.0, sin(turn)) * (solid.radius + 0.7) + Vector3.UP * solid.height)
			var crown := CollisionShape3D.new()
			crown.shape = ConvexPolygonShape3D.new()
			(crown.shape as ConvexPolygonShape3D).points = flare
			body.add_child(crown)
			body.position = at
			body.rotation.y = float(parts[2]) * 0.7
			body.scale = Vector3.ONE * float(parts[3]) / 100.0
			body.add_to_group(&"climbable")
			add_child(body)
		elif name.begins_with("tree_"):
			# (tree_<n>_<seed>_<size%>: a climbable tree of the grove, GameCommon's TreeGen, its limbs to stand on)
			var parts := name.split("_")
			# (150% and up: a great old tree, the shrine tree, grown at its own size so its limbs stay a jump apart;
			# the user, 2026-11-02, "some much bigger and taller trees as well")
			var great := float(parts[3]) >= 150.0
			var tree := TreeGen.preset("Great camphor" if great else "Climbing oak" if int(parts[1]) % 3 != 1 else "Climbing maple")
			tree.seed = int(parts[2])
			var body := tree.body()
			body.position = at
			body.rotation.y = float(parts[2]) * 0.7
			body.scale = Vector3.ONE * (1.0 if great else float(parts[3]) / 100.0)
			body.add_to_group(&"climbable")
			add_child(body)
		elif name.begins_with("check_"):
			_checkpoints.append(at)
		elif name.begins_with("ladder_"):
			# (ladder_<name>_<centimetres high>)
			var ladder := Ladder.new()
			ladder.height = float(name.get_slice("_", name.get_slice_count("_") - 1)) / 100.0
			ladder.transform = markers[name]
			add_child(ladder)
		elif name.begins_with("can_"):
			var can := TrashCan.make(_can_material())
			can.position = at
			can.rotation.y = randf() * TAU
			can.spilled.connect(_on_spilled)
			add_child(can)
			crumbs_total += can.holds
	var k_wire := 0
	while markers.has("wire_%d_a" % k_wire):
		# (Warren's tightrope, from GameCommon godot/tightrope: the user, 2026-11-01, "it should work identical to Warren")
		var wire := Tightrope.new()
		wire.from = markers["wire_%d_a" % k_wire].origin
		wire.to = markers["wire_%d_b" % k_wire].origin
		# (the same sag as tools/build_world1.py lays its crumbs along)
		wire.most_sag = 0.03 * wire.from.distance_to(wire.to)
		add_child(wire)
		k_wire += 1
	if markers.has("trampoline"):
		var bed := Trampoline.new()
		bed.position = markers["trampoline"].origin
		add_child(bed)
	if markers.has("pool"):
		var pool := Pool.new()
		# (its size comes as a marker's position: width, depth, length)
		pool.size = markers.get("pool_size", Transform3D(Basis.IDENTITY, Vector3(4.0, 1.0, 4.0))).origin
		pool.position = markers["pool"].origin
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


## The trash cans' painted metal, a dull green.
func _can_material() -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = WORLD_SHADER
	material.set_shader_parameter(&"tex", load("res://textures/metal.png"))
	material.set_shader_parameter(&"textured", true)
	material.set_shader_parameter(&"box_mapped", true)
	material.set_shader_parameter(&"tile", 0.5)
	material.set_shader_parameter(&"albedo", Color(0.62, 0.8, 0.66))
	return material


## Crumbs out of a can knocked over.
func _on_spilled(spots: Array[Vector3]) -> void:
	for at in spots:
		var crumb := Pickup.make(Pickup.Kind.CRUMB, at)
		crumb.taken.connect(_on_crumb)
		add_child.call_deferred(crumb)
		if zones:
			zones.spilled(crumb)


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


## Gloaming's grass on the lawns, and the skunks, badgers and rabbits out on them (TownGrass, Wildlife). Once the
## physics has the world's bodies in it: the grass asks it what lies over the ground.
func _grow_lawn() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	var lawn := TownGrass.place(self, player, markers)
	Wildlife.place(self, lawn, player)
	# One wind over the hill: Wind Waker ribbons riding it round him, the grass gusting in step (GameCommon wind; the
	# user, 2026-11-02, "there should be Wind Waker like wind trails (we have the assets for that, look at other games)")
	wind = WindField.new()
	wind.speed = 6.0
	for node in get_children():
		if node is Grass:
			wind.apply_grass(node)
	var ribbons := WindRibbons.new()
	ribbons.field = wind
	ribbons.follow_camera = true
	add_child(ribbons)
