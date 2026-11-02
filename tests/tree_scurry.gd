extends SceneTree
## Scurrying up a climbable tree's trunk past its limbs, headless: he should go on up, round a limb that is in his
## way, without catching a limb's edge and hanging from it (the user, 2026-11-02: "you need to work on the ledges on
## the branches, it interrupts your climbing"). Logs his height and state as he goes; PASSED if he gets past the top
## limb's height (or steps up onto a limb he cannot get round) and never hangs.
##   godot --headless --path . --audio-driver Dummy --fixed-fps 60 -s res://tests/tree_scurry.gd [-- <preset> [seed] [angle]]

var player: Player
var eye: Camera3D


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var preset := args[0] if args.size() > 0 else "Climbing oak"
	var seed_given := int(args[1]) if args.size() > 1 else 1
	var angle := float(args[2]) if args.size() > 2 else 0.0
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
	var body := tree.body()
	body.add_to_group(&"climbable")
	level.add_child(body)
	player = (load("res://raccoon.tscn") as PackedScene).instantiate()
	level.add_child(player)
	eye = Camera3D.new()
	level.add_child(eye)
	eye.current = true
	_run.call_deferred(tree, angle)


func _run(tree: TreeGen, angle: float) -> void:
	var out := Vector3(cos(angle), 0.0, sin(angle))
	# (just off the trunk's foot, facing it)
	player.global_position = out * (tree.trunk_radius * 1.9 + 0.5) + Vector3.UP * 0.05
	for _i in 20:
		await physics_frame
	var scurry := player.get_node(^"Scurry") as Scurry
	scurry.button = true
	Input.action_press(&"move_up")
	var top_limb := 0.0
	for walk: PackedVector3Array in tree.walks():
		top_limb = maxf(top_limb, walk[0].y)
	var highest := 0.0
	var hung := 0
	var mounted := 0.0
	var stuck := 0
	var last_y := player.global_position.y
	for f in 900:
		eye.global_transform = Transform3D(Basis.looking_at(-out, Vector3.UP), player.global_position + out * 4.0 + Vector3.UP * 1.5)
		await physics_frame
		highest = maxf(highest, player.global_position.y)
		if player.state == Player.State.HANG:
			hung += 1
		if f % 30 == 0:
			var moved := player.global_position.y - last_y
			last_y = player.global_position.y
			stuck = stuck + 1 if scurry.climbing and absf(moved) < 0.05 else 0
			print("f %3d  y %.2f  state %d  climbing %s  floor %s" % [f, player.global_position.y, player.state, scurry.climbing, player.is_on_floor()])
		if highest > top_limb + 0.5:
			break
		# (or, under a limb he could not get round, stepped up onto it: that is a good end too)
		if player.is_on_floor() and player.global_position.y > 1.0 and f > 30:
			mounted = player.global_position.y
			break
	scurry.button = false
	Input.action_release(&"move_up")
	print("highest %.2f m (top limb %.2f m), hung %d frames%s" % [highest, top_limb, hung, ", stepped onto a limb at %.2f m" % mounted if mounted > 0.0 else ""])
	print("PASSED" if (highest > top_limb + 0.5 or mounted > 0.0) and hung == 0 else "FAILED")
	quit()
