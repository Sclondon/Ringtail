extends SceneTree
## Climbs a climbable tree (GameCommon tree: TreeGen "Climbing oak") as a player would, headless: from the
## ground up onto its lowest limb, then from each limb up onto the next, to the top. Each climb is a run
## and a jump (and, if he catches the limb's edge, a second jump to climb up), steered by the stick
## towards the next limb. Prints the height reached at each and PASSED / FAILED.
##   godot --headless --path . --audio-driver Dummy --fixed-fps 60 -s res://tests/tree_climb.gd [-- <preset> [seed]]

var player: Player
var eye: Camera3D
var preset := "Climbing oak"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		preset = args[0]
	var seed_given := int(args[1]) if args.size() > 1 else 1
	var level := Node3D.new()
	root.add_child(level)
	var ground := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(60, 2, 60)
	shape.shape = box
	shape.position.y = -1.0
	ground.add_child(shape)
	level.add_child(ground)
	var tree := TreeGen.preset(preset)
	tree.seed = seed_given
	level.add_child(tree.body())
	player = (load("res://raccoon.tscn") as PackedScene).instantiate()
	level.add_child(player)
	eye = Camera3D.new()
	level.add_child(eye)
	eye.current = true
	_climb.call_deferred(tree)


func _frames(count: int) -> void:
	for _i in count:
		await physics_frame


## Steers him (by the stick, the camera behind) towards `to`, horizontally.
func _face(to: Vector3) -> void:
	var flat := Vector3(to.x - player.global_position.x, 0.0, to.z - player.global_position.z).normalized()
	eye.global_transform = Transform3D(Basis.looking_at(flat, Vector3.UP), player.global_position - flat * 4.0 + Vector3.UP * 2.0)


## One climb: from where he stands, run and jump at `to` (a point on a walk); climb up if he catches it.
## Whether he ends up standing on it (within `slack` of its height).
func _leap(to: Vector3, slack := 0.35) -> bool:
	_face(to)
	Input.action_press(&"move_up")
	await _frames(4)
	player._queue_jump()
	Input.action_press(&"jump")
	var stood := false
	for f in 150:
		await physics_frame
		_face(to)
		if f == 18:
			Input.action_release(&"jump")
		if player.state == Player.State.HANG and f % 20 == 10:
			player._queue_jump()
		var near := Vector2(player.global_position.x - to.x, player.global_position.z - to.z).length()
		if player.is_on_floor() and absf(player.global_position.y - to.y) < slack and near < 1.2:
			stood = true
			break
		if player.is_on_floor() and f > 40 and player.global_position.y < to.y - 1.0:
			break
	if not stood:
		print("     (ended state %d at %s, aiming at %s)" % [player.state, player.global_position, to])
	Input.action_release(&"move_up")
	Input.action_release(&"jump")
	await _frames(20)
	# (landing on it is the test: a run carried on after landing can still take him off a narrow limb, as in play)
	return stood


## The point on `walk` about `out` metres out from the trunk (horizontally), and the point on `next` nearest it.
func _pair(walk: PackedVector3Array, next: PackedVector3Array, out: float) -> Array:
	var from := walk[0]
	for p in walk:
		if Vector2(p.x, p.z).length() >= out:
			from = p
			break
	var best := Vector3.INF
	for p in next:
		# (not in towards the trunk, which is in the way)
		if Vector2(p.x, p.z).length() < out * 0.85:
			continue
		if best == Vector3.INF or Vector2(p.x - from.x, p.z - from.z).length() < Vector2(best.x - from.x, best.z - from.z).length():
			best = p
	if best == Vector3.INF:
		best = next[next.size() / 2]
	return [from, best]


func _climb(tree: TreeGen) -> void:
	await _frames(5)
	var walks := tree.walks()
	# (the limbs only, in order up the tree: every other walk is a limb's fork)
	var limbs: Array = []
	for k in range(0, walks.size(), 2):
		limbs.append(walks[k])
	var failed := false
	var highest := 0.0
	# From the ground onto the lowest limb: standing a little off to its side, under its middle
	var first: PackedVector3Array = limbs[0]
	var mid := first[first.size() / 2]
	var out := Vector3(mid.x, 0.0, mid.z).normalized()
	var aside := out.cross(Vector3.UP)
	player.global_position = Vector3(mid.x, 0.05, mid.z) + aside * 1.1
	player.velocity = Vector3.ZERO
	await _frames(30)
	var ok := await _leap(mid)
	highest = maxf(highest, player.global_position.y)
	print("%s ground -> limb 0 (top %.2f m): at %.2f m" % ["ok  " if ok else "FAIL", mid.y, player.global_position.y])
	failed = failed or not ok
	# Limb to limb
	for i in limbs.size() - 1:
		var pair := _pair(limbs[i], limbs[i + 1], 1.3)
		var from: Vector3 = pair[0]
		var to: Vector3 = pair[1]
		# (put down on it as if he had walked there: let go of anything first)
		player.state = Player.State.FREE
		player.global_position = from + Vector3.UP * 0.1
		player.velocity = Vector3.ZERO
		await _frames(25)
		var standing := player.is_on_floor()
		ok = standing and await _leap(to)
		highest = maxf(highest, player.global_position.y)
		print("%s limb %d -> limb %d (%.2f m up, %.2f m across): at %.2f m%s" % ["ok  " if ok else "FAIL", i, i + 1,
			to.y - from.y, Vector2(to.x - from.x, to.z - from.z).length(), player.global_position.y, "" if standing else " (could not stand on limb %d)" % i])
		failed = failed or not ok
	print("highest %.2f m of a tree %.1f m high" % [highest, tree.built_height])
	print("FAILED" if failed else "PASSED")
	quit(1 if failed else 0)
