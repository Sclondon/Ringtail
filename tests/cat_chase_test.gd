extends SceneTree
## The yard cat's chase (YardCat; the user, 2026-11-02: "the cats should have more complex behaviour, stalking around
## climbing houses and walking along wires"): in the playground, with a house and its drainpipe, two poles and a wire
## between them added here. A cat stalks him on the ground and pounces; leaps up onto a wall after him; climbs a
## drainpipe onto a roof after him; climbs a pole and walks the wire to him; and gives up on him out of reach and
## goes home. Headless:
##   godot --headless --path . --audio-driver Dummy --fixed-fps 60 -s res://tests/cat_chase_test.gd
## With `-- --out=<dir>` (in a window) it also photographs the stalk, the climb and the wire walk.

var failures: Array[String] = []
var level: Node3D
var player: Player
var out := ""
var eye: Camera3D
var view: SubViewport


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.substr(6)
			DirAccess.make_dir_recursive_absolute(out)
	level = (load("res://scenes/playground.tscn") as PackedScene).instantiate()
	root.add_child(level)
	_run.call_deferred()


func _check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)
	if not ok:
		failures.append(what)


func _box(at: Vector3, size: Vector3, colour: Color, climbable := false) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = at
	var shape := BoxShape3D.new()
	shape.size = size
	var collider := CollisionShape3D.new()
	collider.shape = shape
	body.add_child(collider)
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	box.material = material
	mesh.mesh = box
	body.add_child(mesh)
	if climbable:
		body.add_to_group(&"climbable")
	level.add_child(body)
	return body


func _cat(at: Vector3) -> YardCat:
	var cat := YardCat.make()
	cat.position = at
	level.add_child(cat)
	cat.target = player
	return cat


func _put(at: Vector3) -> void:
	player.global_position = at
	player.velocity = Vector3.ZERO


## Waits up to `frames` for `done` to hold, each frame; true if it did.
func _until(frames: int, done: Callable) -> bool:
	for _i in frames:
		await physics_frame
		if done.call():
			return true
	return false


func _shot(name: String, at: Node3D, from: Vector3) -> void:
	if out.is_empty():
		return
	if eye == null:
		# (a view of its own: the playground's follow camera keeps taking the window's)
		view = SubViewport.new()
		view.size = Vector2i(480, 400)
		view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(view)
		eye = Camera3D.new()
		eye.fov = 45.0
		view.add_child(eye)
	eye.global_position = at.global_position + from
	eye.look_at(at.global_position + Vector3.UP * 0.3)
	eye.current = true
	for _i in 3:
		await RenderingServer.frame_post_draw
	view.get_texture().get_image().save_png("%s/cat_%s.png" % [out, name])


func _run() -> void:
	await process_frame
	player = level.player
	# (no grove here: Hazards.haven's default sits under the playground's middle, which would make it all safe)
	Hazards.haven = Vector3(1.0e6, 0.0, 1.0e6)
	# (he only stands where he is put: in a window a gamepad in use elsewhere reaches him)
	player.takes_input = false
	# The house (its roof 3.2 m up, too high to leap) with a drainpipe up its west wall; two poles and a wire
	_box(Vector3(16.0, 1.6, 0.0), Vector3(4.0, 3.2, 4.0), Color(0.75, 0.68, 0.55))
	_box(Vector3(13.92, 1.6, 0.6), Vector3(0.14, 3.2, 0.14), Color(0.5, 0.5, 0.52), true)
	_box(Vector3(12.0, 2.1, -12.0), Vector3(0.24, 4.2, 0.24), Color(0.45, 0.4, 0.35), true)
	_box(Vector3(20.0, 2.1, -12.0), Vector3(0.24, 4.2, 0.24), Color(0.45, 0.4, 0.35), true)
	var wire := Tightrope.new()
	wire.from = Vector3(12.0, 4.0, -12.0)
	wire.to = Vector3(20.0, 4.0, -12.0)
	wire.most_sag = 0.2
	level.add_child(wire)
	for _i in 10:
		await physics_frame

	# 1. On the ground: it stalks him low, crouches and pounces
	_put(Vector3(4.0, 0.05, 12.0))
	var cat := _cat(Vector3(4.0, 0.05, 16.5))
	var stalked := await _until(240, func() -> bool: return cat.mode == YardCat.Mode.STALK)
	if stalked:
		for _i in 30:
			await physics_frame
		await _shot("stalk", cat, Vector3(2.5, 1.2, 1.5))
	var pounced := await _until(600, func() -> bool: return cat.mode == YardCat.Mode.POUNCE)
	_check(stalked and pounced, "it stalks him on the ground and pounces")
	cat.queue_free()

	# 2. He is up on a wall (2.1 m): it leaps up after him
	_put(Vector3(1.5, 2.2, 8.0))
	cat = _cat(Vector3(1.5, 0.05, 3.0))
	var leapt := await _until(600, func() -> bool: return cat.global_position.y > 1.9 and cat.is_on_floor())
	_check(leapt, "it leaps up onto a wall after him (%.2f)" % cat.global_position.y)
	cat.queue_free()

	# 3. He is on the roof: it climbs the drainpipe and gets onto the roof
	_put(Vector3(16.5, 3.3, 0.0))
	cat = _cat(Vector3(10.0, 0.05, 0.5))
	var climbing := await _until(900, func() -> bool: return cat.mode == YardCat.Mode.CLIMB and cat._climb_started)
	if climbing:
		for _i in 25:
			await physics_frame
		await _shot("climb", cat, cat._climb_out * 2.2 + cat._climb_out.cross(Vector3.UP) * 1.2 + Vector3.UP * 0.4)
	var on_roof := await _until(600, func() -> bool: return cat.mode != YardCat.Mode.CLIMB and cat.global_position.y > 3.0 and cat.is_on_floor())
	_check(climbing and on_roof, "it climbs the drainpipe onto the roof after him (climbed %s, at %.2f)" % [climbing, cat.global_position.y])
	cat.queue_free()

	# 4. He is out on the wire: it climbs a pole and walks the wire to him
	_put(Vector3(17.5, 4.6, -12.0))
	wire.bodies_now()
	await _until(120, func() -> bool: return player.is_on_floor() and wire.carries(player.global_position))
	_check(wire.carries(player.global_position), "he stands on the wire (tightrope %.2f)" % player.tightrope)
	cat = _cat(Vector3(13.5, 0.05, -8.0))
	var walking := await _until(1200, func() -> bool: return cat.mode == YardCat.Mode.WIRE)
	if walking:
		for _i in 40:
			await physics_frame
		await _shot("wire", cat, Vector3(1.2, 0.5, -3.0))
	var along := await _until(600, func() -> bool: return cat.mode != YardCat.Mode.WIRE or cat.global_position.distance_to(player.global_position) < 1.3)
	_check(walking and along, "it climbs a pole and walks the wire to him (on the wire %s)" % walking)
	cat.queue_free()

	# 5. He is out of its reach (on the 5 m block, nothing to climb): it gives up and goes home, then leaves him be
	_put(Vector3(-8.0, 5.1, 4.0))
	cat = _cat(Vector3(-4.0, 0.05, 4.0))
	var home := cat.global_position
	var chased := await _until(300, func() -> bool: return cat.mode == YardCat.Mode.CHASE)
	var gave_up := await _until(60 * 20, func() -> bool: return cat.mode == YardCat.Mode.HOME)
	_check(chased and gave_up, "out of reach, it gives up the chase (chased %s)" % chased)
	var back := await _until(60 * 12, func() -> bool: return cat.mode == YardCat.Mode.WANDER)
	_check(back and cat.global_position.distance_to(home) < 4.0, "and goes home (%.1f m off)" % cat.global_position.distance_to(home))
	# Sat washing, for the pictures
	if not out.is_empty():
		_put(Vector3(-20.0, 0.05, -20.0))
		cat = _cat(Vector3(6.0, 0.05, -6.0))
		cat.target = null
		cat._sit_for = 30.0
		cat._washing = true
		cat._go(YardCat.Mode.SIT)
		for _i in 90:
			await physics_frame
		await _shot("wash", cat, cat.global_basis.z * 1.6 + cat.global_basis.x * 0.8 + Vector3.UP * 0.5)
	print("PASSED" if failures.is_empty() else "FAILED: " + ", ".join(failures))
	quit()
