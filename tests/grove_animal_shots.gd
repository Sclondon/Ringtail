extends SceneTree
## Pictures of the grove's animals (GroveAnimals): every kind in a row beside the raccoon (upright, his height for
## scale), from the front and from the side; then the grove as played, from above and close by the pond, the food
## pile and the burrows, and a count of who is where (and that none has fallen through the ground).
##   godot --path . --audio-driver Dummy --fixed-fps 60 --resolution 1280x720 -s res://tests/grove_animal_shots.gd -- --out=<dir> [lineup] [grove]
## Needs a window (kept off the screen).

const KINDS := ["skunk", "rabbit", "beaver", "otter", "rat", "mouse", "weasel", "marten", "gopher", "prairie_dog",
		"opossum", "squirrel", "porcupine", "chipmunk"]

var out := "user://grove_animal_shots"
var parts: Array[String] = []


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.substr(6)
		else:
			parts.append(arg)
	if parts.is_empty():
		parts = ["lineup", "grove"]
	DirAccess.make_dir_recursive_absolute(out)
	root.position = Vector2i(-3000, 0)
	_run.call_deferred()


func _frames(count: int) -> void:
	for _i in count:
		await physics_frame


func _shot(name: String) -> void:
	for _f in 4:
		await process_frame
	root.get_texture().get_image().save_png(out.path_join(name + ".png"))
	print("SHOT ", name)


func _run() -> void:
	if "lineup" in parts:
		await _lineup()
	if "grove" in parts:
		await _grove()
	print("GROVE ANIMAL SHOTS DONE ", out)
	quit()


func _lineup() -> void:
	var level: Node3D = load("res://scenes/playground.tscn").instantiate()
	root.add_child(level)
	var eye := Camera3D.new()
	level.add_child(eye)
	eye.current = true
	var at := Vector3(14.0, 0.05, -14.0)
	# (him, upright as he stands: a critter body on his own model)
	var him := Critter.new()
	him.rig = CritterRig.new()
	him.rig.kind = "fox"
	him.rig.model = load("res://models/raccoon.glb")
	him.rig.tail_stand = CritterRig.TAILS["fox"][0]
	him.rig.tail_run = CritterRig.TAILS["fox"][1]
	him.rig.tail_quad = CritterRig.TAILS["fox"][2]
	him.rig.dusty = false
	him.position = at
	level.add_child(him)
	var row: Array[Critter] = [him]
	var x := 0.0
	for kind: String in KINDS:
		var size: float = Critter.SIZES[kind]
		x += 0.35 + size * 0.45
		var beast := Critter.make(kind, true)
		beast.position = at + Vector3(x, 0.0, 0.0)
		level.add_child(beast)
		row.append(beast)
		x += size * 0.45
	await _frames(60)
	var middle := at + Vector3(x * 0.5, 0.3, 0.0)
	# (front: every one faces +Z)
	eye.fov = 22.0
	eye.global_position = middle + Vector3(0.0, 0.5, x * 1.25 + 2.0)
	eye.look_at(middle, Vector3.UP)
	await _shot("lineup_front")
	for beast in row:
		beast.rotation.y = PI * 0.5
	await _frames(10)
	await _shot("lineup_side")
	# (close halves, to see the small ones)
	for half in 2:
		var mid := at + Vector3(x * (0.25 + 0.5 * half), 0.25, 0.0)
		eye.global_position = mid + Vector3(0.0, 0.35, x * 0.65 + 1.0)
		eye.look_at(mid, Vector3.UP)
		await _shot("lineup_side_%d" % half)
	level.queue_free()
	await process_frame


func _grove() -> void:
	var world: World = (load("res://scenes/world1.tscn") as PackedScene).instantiate()
	root.add_child(world)
	await _frames(120)
	var life := world.get_node_or_null(^"GroveAnimals") as GroveAnimals
	if life == null:
		print("GROVE FAIL: no GroveAnimals")
		return
	var counts := {}
	var fallen := 0
	for beast in life.beasts:
		counts[beast.kind] = int(counts.get(beast.kind, 0)) + 1
		if beast.global_position.y < life.heart.y - 25.0:
			fallen += 1
	print("GROVE animals=%d fallen=%d %s" % [life.beasts.size(), fallen, counts])
	# (him at the heart, so all are awake)
	world.player.global_position = life.heart + Vector3.UP * 0.3
	await _frames(240)
	var doing := {}
	for beast in life.beasts:
		var what: String = GroveAnimals.Doing.keys()[life._life[beast]["doing"]]
		doing[what] = int(doing.get(what, 0)) + 1
	print("GROVE doing ", doing)
	var eye := Camera3D.new()
	world.add_child(eye)
	eye.current = true
	eye.global_position = life.heart + Vector3(0.0, 30.0, 26.0)
	eye.look_at(life.heart, Vector3.UP)
	await _shot("grove_above")
	# (close by a few of each place's animals)
	var seen := {}
	for beast in life.beasts:
		var where: String = beast.kind
		if seen.has(where) or not beast.kind in ["otter", "mouse", "prairie_dog", "squirrel", "skunk", "porcupine", "opossum"]:
			continue
		seen[where] = true
		var at := beast.global_position + Vector3.UP * 0.3
		eye.global_position = at + Vector3(2.2, 1.2, 2.2)
		eye.look_at(at, Vector3.UP)
		await _shot("grove_" + where)
