extends SceneTree
## The owl (HazardOwl) and the crows (HazardBird on BirdBody) on a flat yard: the owl perches on a pole top from the
## markers, stares when the raccoon comes near, swoops and hurts him, beats back and lands on its perch again; not
## while he is in the grove. A crow band hops, folded, and dives at him. Prints a line for each check and PASSED or
## FAILED. Headless:
##   godot --headless --path . --audio-driver Dummy --fixed-fps 60 -s res://tests/owl_test.gd

class Game:
	extends Node3D
	var hurts := 0

	func _init() -> void:
		add_to_group(&"game")

	func hurt(_at: Vector3) -> void:
		hurts += 1


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
	player.position = Vector3(0.0, 0.05, 0.0)
	game.add_child(player)
	var markers := {
		"grove_heart": Transform3D(Basis.IDENTITY, Vector3(0, 0, 0)),
		# (a pole in the grove, and two out of it: the owls take the two out of it)
		"wire_0_a": Transform3D(Basis.IDENTITY, Vector3(5, 6, 0)),
		"wire_0_b": Transform3D(Basis.IDENTITY, Vector3(40, 6, 0)),
		"wire_1_a": Transform3D(Basis.IDENTITY, Vector3(-40, 6, 0)),
		"wire_1_b": Transform3D(Basis.IDENTITY, Vector3(-40, 6, 30)),
		"crows_0": Transform3D(Basis.IDENTITY, Vector3(0, 0, -40)),
	}
	Hazards.place(game, markers, player)
	HazardOwl.place(game, markers, player)
	_run.call_deferred()


func _check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)
	if not ok:
		failures.append(what)


func _frames(count: int) -> void:
	for _i in count:
		await physics_frame


func _run() -> void:
	await _frames(10)
	var owls: Array = game.get_children().filter(func(n: Node) -> bool: return n is HazardOwl)
	_check(owls.size() == 2, "two owls, on the poles out of the grove (%d)" % owls.size())
	var owl: HazardOwl = null
	for o: HazardOwl in owls:
		_check(not Hazards.safe(o.perch), "an owl's perch is out of the grove (%s)" % o.perch)
		if o.perch.is_equal_approx(Vector3(40, 6, 0)):
			owl = o
	if owl == null:
		print("FAILED")
		quit()
		return
	# In the grove, near a pole: nothing
	player.global_position = Vector3(3.0, 0.05, 2.0)
	await _frames(240)
	_check(game.hurts == 0, "nothing hunts him in the grove")
	# Out by the owl's pole: it stares, swoops and hurts him, then goes back
	owl._rest_left = 0.0
	player.global_position = Vector3(37.0, 0.05, 3.0)
	var stared := false
	var swooped := false
	for _i in 300:
		await physics_frame
		stared = stared or owl.state == HazardOwl.State.STARE
		swooped = swooped or owl.state == HazardOwl.State.SWOOP
		if game.hurts > 0:
			break
	_check(stared and swooped, "the owl stares, then swoops")
	_check(game.hurts > 0, "its swoop hurts him")
	# He goes away: it goes back to its perch
	player.global_position = Vector3(10.0, 0.05, 40.0)
	var perched := false
	for _i in 900:
		await physics_frame
		if owl.state == HazardOwl.State.PERCH:
			perched = true
			break
	_check(perched and owl.global_position.distance_to(owl.perch) < 0.05, "back on its perch")
	# The crows: on BirdBody, folded on the ground, one dives at him when he is near
	var crows: Array = []
	for node in game.find_children("*", "HazardBird", true, false):
		if (node as HazardBird).kind == HazardBird.Kind.CROW:
			crows.append(node)
	_check(crows.size() >= 3 and (crows[0] as HazardBird)._bird != null, "crows on the new crow model (%d)" % crows.size())
	# (those sitting, on the ground or up on a perch, are folded; they fly between perches now and then)
	var sitting := crows.filter(func(c: HazardBird) -> bool: return c.state == HazardBird.State.GROUND or c.state == HazardBird.State.PERCH)
	_check(not sitting.is_empty() and sitting.all(func(c: HazardBird) -> bool: return c._bird.fold > 0.5), "crows sitting folded (%d of %d)" % [sitting.size(), crows.size()])
	var hurts_before := game.hurts
	player.global_position = Vector3(1.5, 0.05, -38.0)
	var dove := false
	for _i in 400:
		await physics_frame
		for c: HazardBird in crows:
			dove = dove or (c.state == HazardBird.State.DIVE and c._bird.fold < 0.6)
	_check(dove, "a crow dives at him, wings half open")
	_check(game.hurts > hurts_before, "a crow's dive hurts him")
	print("FAILED" if failures.size() > 0 else "PASSED")
	quit()
