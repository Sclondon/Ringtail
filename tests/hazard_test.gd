extends SceneTree
## The hazards on a flat yard, through Hazards.place with markers as a world has them; prints a line for each check
## and PASSED or FAILED. Headless:
##   godot --headless --path . --audio-driver Dummy --fixed-fps 60 -s res://tests/hazard_test.gd

class Game:
	extends Node3D
	var hurts := 0
	var last := Vector3.ZERO

	func _init() -> void:
		add_to_group(&"game")

	func hurt(at: Vector3) -> void:
		hurts += 1
		last = at


var game: Game
var player: Player
var failures: Array[String] = []


func _initialize() -> void:
	game = Game.new()
	root.add_child(game)
	var floor_body := StaticBody3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(160.0, 2.0, 160.0)
	var collider := CollisionShape3D.new()
	collider.shape = shape
	floor_body.add_child(collider)
	floor_body.position.y = -1.0
	game.add_child(floor_body)
	player = (load("res://raccoon.tscn") as PackedScene).instantiate()
	player.position = Vector3(0.0, 0.05, -40.0)
	game.add_child(player)
	Hazards.place(game, markers(), player)
	_run.call_deferred()


static func markers() -> Dictionary:
	var m := {}
	var square := [Vector3(-20, 0, -20), Vector3(20, 0, -20), Vector3(20, 0, 20), Vector3(-20, 0, 20)]
	for i in square.size():
		m["road_0_%d" % i] = Transform3D(Basis.IDENTITY, square[i])
	m["walk_0_0"] = Transform3D(Basis.IDENTITY, Vector3(-8, 0.05, 6))
	m["walk_0_1"] = Transform3D(Basis.IDENTITY, Vector3(8, 0.05, 6))
	m["hawk_0"] = Transform3D(Basis.IDENTITY, Vector3(0, 0, -6))
	m["crows_0"] = Transform3D(Basis.IDENTITY, Vector3(10, 0, 12))
	m["den_0"] = Transform3D(Basis.IDENTITY, Vector3(-10, 0.05, 12))
	return m


func _check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)
	if not ok:
		failures.append(what)


func _frames(count: int) -> void:
	for _i in count:
		await physics_frame


## Only these hazards work (the rest are still), so each check is of one thing.
func _only(group: StringName) -> void:
	for node in get_nodes_in_group(&"hazards"):
		var on: bool = node.is_in_group(group)
		node.process_mode = Node.PROCESS_MODE_INHERIT if on else Node.PROCESS_MODE_DISABLED
	for band in game.get_children():
		if band is HazardCrows:
			band.process_mode = Node.PROCESS_MODE_INHERIT if group == &"crows" else Node.PROCESS_MODE_DISABLED
			for crow in band.crows:
				crow.process_mode = band.process_mode


func _put(at: Vector3) -> void:
	player.global_position = at
	player.velocity = Vector3.ZERO
	await _frames(3)


func _run() -> void:
	await _frames(10)
	var cars := get_nodes_in_group(&"cars")
	var people := get_nodes_in_group(&"people")
	var hawk: HazardBird
	var fox: HazardFox
	var crows: Array = []
	for node in get_nodes_in_group(&"hazards"):
		if node is HazardBird and node.kind == HazardBird.Kind.HAWK:
			hawk = node
			hawk.add_to_group(&"hawk")
		elif node is HazardBird:
			crows.append(node)
			node.add_to_group(&"crows")
		elif node is HazardFox:
			fox = node
			fox.add_to_group(&"fox")
	_check(cars.size() == Hazards.CARS_PER_LOOP and people.size() == 2 and hawk != null and crows.size() == 4 and fox != null,
		"placed: %d cars, %d people, hawk, %d crows, fox" % [cars.size(), people.size(), crows.size()])

	# Cars drive round
	_only(&"cars")
	var car: HazardCar = cars[0]
	var from := car.global_position
	await _frames(180)
	_check(car.global_position.distance_to(from) > 8.0, "a car drives round its loop (%.1f m)" % car.global_position.distance_to(from))

	# He rides on a car's roof
	car._stop_left = 0.0
	car._stop_wait = 99.0
	# (on its roof, whatever kind it is)
	await _put(car.global_position + Vector3.UP * (car.half_size.y * 2.0 + 0.15))
	var on := player.global_position
	await _frames(60)
	_check(player.global_position.distance_to(on) > 2.0 and player.global_position.y > 1.2,
		"he rides on a car's roof (%.1f m, at %.2f m up)" % [player.global_position.distance_to(on), player.global_position.y])

	# Run into by a car, he is hurt
	var hurts := game.hurts
	var ahead := car.global_transform * Vector3(0.0, 0.05, car.half_size.z + 0.4)
	await _put(Vector3(ahead.x, 0.05, ahead.z))
	await _frames(20)
	_check(game.hurts > hurts, "a car running into him hurts")
	await _put(Vector3(0.0, 0.05, -40.0))

	# People stroll, start at him, chase, stamp
	_only(&"people")
	var person: HazardPerson = people[0]
	from = person.global_position
	await _frames(90)
	_check(person.global_position.distance_to(from) > 0.5, "a person strolls their walk")
	hurts = game.hurts
	await _put(person.global_position + Vector3(2.5, 0.0, 0.0))
	var chased := false
	for _i in 300:
		await physics_frame
		chased = chased or person.mood == HazardPerson.State.CHASE or person.mood == HazardPerson.State.STAMP
		if game.hurts > hurts:
			break
	_check(chased, "a person starts at him and gives chase")
	_check(game.hurts > hurts, "a person's stamp hurts him")
	await _put(Vector3(0.0, 0.05, -40.0))

	# The hawk circles, warns, dives
	_only(&"hawk")
	hurts = game.hurts
	hawk._rest_left = 0.0
	await _put(Vector3(0.0, 0.05, -6.0))
	var stalked := false
	var dived := false
	for _i in 900:
		await physics_frame
		player.velocity = Vector3.ZERO
		stalked = stalked or hawk.state == HazardBird.State.STALK
		dived = dived or hawk.state == HazardBird.State.DIVE
		if game.hurts > hurts:
			break
	_check(stalked and dived, "the hawk circles in over him, then dives")
	_check(game.hurts > hurts, "the hawk's dive hurts him")
	await _put(Vector3(0.0, 0.05, -40.0))

	# Crows dive-bomb him when he is near
	_only(&"crows")
	await _frames(30)
	hurts = game.hurts
	await _put(Vector3(10.0, 0.05, 15.0))
	var bombed := false
	for _i in 600:
		await physics_frame
		player.velocity = Vector3.ZERO
		for crow in crows:
			bombed = bombed or crow.state == HazardBird.State.DIVE
		if game.hurts > hurts:
			break
	_check(bombed, "the crows dive-bomb him")
	_check(game.hurts > hurts, "a crow's dive hurts him")

	# His tail spin knocks a bird away
	await _frames(120)
	var crow: HazardBird = crows[0]
	crow.process_mode = Node.PROCESS_MODE_DISABLED
	crow.global_position = Vector3(0.0, 0.0, -30.0)
	await _put(Vector3(0.0, 0.05, -31.0))
	crow.process_mode = Node.PROCESS_MODE_INHERIT
	# (put down, its time there starting now: else it is up and off to a perch at once)
	crow._go(HazardBird.State.GROUND)
	(player.get_node(^"TailMoves") as TailMoves).press()
	var knocked := false
	for _i in 40:
		await physics_frame
		knocked = knocked or crow.state == HazardBird.State.KNOCKED
	_check(knocked, "his tail spin knocks a crow tumbling")
	hawk.tail_hit(Vector3.ZERO, Vector3(5, 2, 0))
	_check(hawk.state == HazardBird.State.KNOCKED, "the hawk can be knocked too")

	# The fox chases and bites
	_only(&"fox")
	hurts = game.hurts
	await _put(Vector3(-10.0, 0.05, 6.0))
	var chasing := false
	for _i in 400:
		await physics_frame
		player.velocity = Vector3.ZERO
		chasing = chasing or fox.mood == HazardFox.State.CHASE
		if game.hurts > hurts:
			break
	_check(chasing, "the fox gives chase")
	_check(game.hurts > hurts, "the fox's bite hurts him")
	fox.tail_hit(Vector3.ZERO, Vector3(3, 2, 0))
	_check(fox.mood == HazardFox.State.DAZED, "his tail sends the fox reeling")

	print("PASSED" if failures.is_empty() else "FAILED: " + ", ".join(failures))
	quit(0 if failures.is_empty() else 1)
