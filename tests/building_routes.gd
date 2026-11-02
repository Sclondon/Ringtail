extends SceneTree
## Walks the raccoon up each generated building's route (tools/buildings.py, built into models/buildings_preview.glb
## by tools/build_building_preview.py): for every link he is put where it starts and does what it says (walk, run up
## the stairs or a slope, jump, jump and catch the ledge and pull up, scurry up the climbable, climb the ladder) towards
## where it ends, the camera behind him; it passes when he stands there. Prints each link, each building's verdict and
## PASSED/FAILED. Headless:
##   godot --headless --path . --audio-driver Dummy --fixed-fps 60 -s res://tests/building_routes.gd [-- <name prefix>]

const SECONDS := {"walk": 6.0, "stairs": 10.0, "slope": 8.0, "jump": 3.0, "ledge": 4.0, "climb": 16.0, "ladder": 14.0}

var player: Player
var scurry: Scurry
var eye: Camera3D
var failures: Array[String] = []


func _initialize() -> void:
	_setup.call_deferred()


func _setup() -> void:
	var level: Node3D = (load("res://models/buildings_preview.glb") as PackedScene).instantiate()
	root.add_child(level)
	# (as World makes its level: solid unless nocol_, climb_ climbable, _hidden unseen)
	for mesh: MeshInstance3D in level.find_children("*", "MeshInstance3D", true, false):
		var called := String(mesh.name)
		if called.begins_with("hidden_") or called.ends_with("_hidden"):
			mesh.visible = false
		if called.begins_with("climb_"):
			mesh.add_to_group(&"climbable")
		if not called.begins_with("nocol_"):
			mesh.create_trimesh_collision()
			for shape: CollisionShape3D in mesh.find_children("*", "CollisionShape3D", true, false):
				(shape.shape as ConcavePolygonShape3D).backface_collision = true
	var routes := {}
	for node: Node in level.find_children("*", "", true, false):
		var called := String(node.name)
		if called.begins_with("ladder_"):
			var ladder := Ladder.new()
			ladder.height = float(called.get_slice("_", called.get_slice_count("_") - 1)) / 100.0
			level.add_child(ladder)
			ladder.global_transform = (node as Node3D).global_transform
		elif called.begins_with("route_"):
			# (route_<building>_<i>_<how>)
			var parts := called.split("_")
			var how := parts[parts.size() - 1]
			var index := int(parts[parts.size() - 2])
			var building := "_".join(parts.slice(1, parts.size() - 2))
			if not routes.has(building):
				routes[building] = []
			routes[building].append([index, how, (node as Node3D).global_position])
	player = (load("res://raccoon.tscn") as PackedScene).instantiate()
	root.add_child(player)
	scurry = player.get_node(^"Scurry") as Scurry
	eye = Camera3D.new()
	root.add_child(eye)
	eye.current = true
	await physics_frame
	_run(routes)


func _let_go() -> void:
	for action: StringName in [&"move_up", &"jump", &"duck"]:
		Input.action_release(action)
	scurry.button = false


func _run(routes: Dictionary) -> void:
	var args := OS.get_cmdline_user_args()
	var only := args[0] if args.size() > 0 else ""
	var names := routes.keys()
	names.sort()
	for building: String in names:
		if only != "" and not building.begins_with(only):
			continue
		var route: Array = routes[building]
		route.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
		var good := true
		for k in range(1, route.size()):
			var ok := await _link(route[k - 1][2], route[k][2], route[k][1])
			print("  %s %02d %-6s %s -> %s  %s" % [building, k, route[k][1], _v(route[k - 1][2]), _v(route[k][2]), ok])
			if ok != "ok":
				good = false
		print(("ok   " if good else "FAIL ") + building)
		if not good:
			failures.append(building)
	print("PASSED" if failures.is_empty() else "FAILED: " + ", ".join(failures))
	quit()


func _v(p: Vector3) -> String:
	return "(%.1f, %.1f, %.1f)" % [p.x, p.y, p.z]


## Does one link: returns "ok" or what went wrong.
func _link(a: Vector3, b: Vector3, how: String) -> String:
	_let_go()
	player.state = Player.State.FREE
	player.velocity = Vector3.ZERO
	player.global_position = a + Vector3.UP * 0.08
	var way := Vector3(b.x - a.x, 0.0, b.z - a.z)
	if way.length() < 0.01:
		way = Vector3.FORWARD
	player.facing_yaw = atan2(-way.x, -way.z)
	_aim(way.normalized())
	for _i in 12:
		await physics_frame
	if player.global_position.distance_to(a) > 0.6:
		return "cannot stand at the start (at %s)" % _v(player.global_position)
	# (a long walk gets the time it takes at a run)
	var frames := int(maxf(SECONDS.get(how, 6.0), Vector2(b.x - a.x, b.z - a.z).length() / 1.6 + 3.0) * 60.0)
	var hung := false
	for f in frames:
		var here := player.global_position
		var flat := Vector3(b.x - here.x, 0.0, b.z - here.z)
		var near := flat.length()
		if near > 0.05:
			_aim(flat.normalized())
		# (pushing on towards it; let go of the stick once over it, in the air, so as not to run past)
		var push := near > 0.3 or player.state != Player.State.FREE
		if push:
			Input.action_press(&"move_up", 0.9)
		else:
			Input.action_release(&"move_up")
		if how == "climb":
			scurry.button = true
		if how in ["jump", "ledge"]:
			if f == 2:
				player._queue_jump()
				Input.action_press(&"jump")
			elif f == 16:
				Input.action_release(&"jump")
		if player.state == Player.State.HANG:
			hung = true
			if f % 20 == 0:
				player._queue_jump()
				Input.action_press(&"jump")
			elif f % 20 == 3:
				Input.action_release(&"jump")
		await physics_frame
		var at := player.global_position
		var arrived := player.is_on_floor() and player.state == Player.State.FREE and Vector2(at.x - b.x, at.z - b.z).length() < 0.9 and absf(at.y - b.y) < 0.45
		if how == "climb":
			arrived = player.is_on_floor() and not scurry.climbing and at.y > b.y - 0.7 and Vector2(at.x - b.x, at.z - b.z).length() < 2.2
		if arrived:
			_let_go()
			return "ok"
	_let_go()
	var at := player.global_position
	return "did not get there: at %s%s, state %d" % [_v(at), " (hung)" if hung else "", player.state]


func _aim(way: Vector3) -> void:
	eye.global_transform = Transform3D(Basis.looking_at(way, Vector3.UP), player.global_position - way * 4.0 + Vector3.UP * 1.8)
