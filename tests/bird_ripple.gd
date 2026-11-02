extends SceneTree
## The birds' wings as a skeleton with sprung feathers (BirdBody): each bird flown round a circle beating, then
## gliding, then folded on the ground. Checks that every bone and feather part was found, that the feathers ripple in
## flight (bend and move) and settle folded, that the tail fans open flying and closed folded, and that no part turns
## more than SHAKE radians from one frame to the next (prints a SHAKE line for any that flips). Headless:
##   godot --headless --path . --audio-driver Dummy --fixed-fps 60 -s res://tests/bird_ripple.gd

const SHAKE := 0.5
var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)
	if not ok:
		failures.append(what)


func _run() -> void:
	for kind: StringName in [&"crow", &"owl", &"hawk"]:
		var bird := BirdBody.make(kind)
		root.add_child(bird)
		var bones := 0
		for joint in ["_wing_l", "_wing_l_fore", "_wing_l_hand", "_wing_l_digit", "_wing_l_alula", "_wing_r_digit", "_tail"]:
			bones += 1 if bird._parts.has(joint) else 0
		var counts := {}
		for f: BirdBody.Feather in bird._feathers:
			counts[f.kind] = counts.get(f.kind, 0) + 1
		_check(bones == 7, "%s: the wing's bones and the tail (%d of 7)" % [kind, bones])
		_check(counts.get(BirdBody.Kind.PRIMARY, 0) >= 14 and counts.get(BirdBody.Kind.SECONDARY, 0) >= 14
				and counts.get(BirdBody.Kind.TERTIAL, 0) >= 6 and counts.get(BirdBody.Kind.COVERT, 0) == 6
				and counts.get(BirdBody.Kind.TAIL, 0) >= 8, "%s: feathers each their own part %s" % [kind, counts])
		var parts: Array[Node3D] = []
		for n: Node in bird.find_children("*", "Node3D", true, false):
			if n is MeshInstance3D:
				parts.append(n)
		var last := {}
		var worst := 0.0
		var worst_at := ""
		var flown_bend := 0.0
		var flown_moves := 0.0
		var open_fan := 0.0
		var t := 0.0
		# Flying: beating round a circle (3 s), then gliding (2 s); then down and folded (2.5 s)
		for frame in 450:
			var dt := 1.0 / 60.0
			t += dt
			var flying := frame < 300
			bird.fold = 0.0 if flying else 1.0
			bird.flap = 1.0 if frame < 180 else 0.0
			bird.tuck = 1.0 if flying else 0.0
			if flying:
				var a := t * 0.9
				bird.position = Vector3(cos(a) * 8.0, 3.0, sin(a) * 8.0)
				bird.rotation.y = -a
			await process_frame
			for p in parts:
				var b := p.basis.orthonormalized()
				if last.has(p):
					var turn := (last[p] as Basis).inverse() * b
					var angle := turn.get_rotation_quaternion().get_angle()
					# (frame 1 is the first posed from the unturned rest)
					if angle > worst and frame > 1:
						worst = angle
						worst_at = "%s at frame %d" % [p.name, frame]
				last[p] = b
			if flying and frame > 60:
				for f: BirdBody.Feather in bird._feathers:
					flown_bend = maxf(flown_bend, absf(f.bend))
					flown_moves = maxf(flown_moves, absf(f.bend_v))
			if frame == 290:
				open_fan = _fan(bird)
		var settled := 0.0
		for f: BirdBody.Feather in bird._feathers:
			settled = maxf(settled, absf(f.bend) + absf(f.twist))
		var closed_fan := _fan(bird)
		if worst > SHAKE:
			print("SHAKE %s %.2f rad in one frame (%s)" % [kind, worst, worst_at])
		_check(worst <= SHAKE, "%s: no part flips between frames (most %.2f rad, %s)" % [kind, worst, worst_at])
		_check(flown_bend > 0.06 and flown_moves > 0.5, "%s: flying, the feathers ripple (bend to %.2f rad, %.1f rad/s)" % [kind, flown_bend, flown_moves])
		_check(settled < 0.02, "%s: folded, they settle (%.3f rad)" % [kind, settled])
		_check(open_fan > closed_fan * 1.6, "%s: the tail fans open flying (%.2f rad edge to edge) and closes folded (%.2f)" % [kind, open_fan, closed_fan])
		bird.queue_free()
	print("PASSED" if failures.is_empty() else "FAILED: " + ", ".join(failures))
	quit()


## How wide the tail is fanned: the angle between its outermost feathers.
func _fan(bird: BirdBody) -> float:
	var outer: Array[Vector3] = []
	for f: BirdBody.Feather in [bird._tail_feathers.front(), bird._tail_feathers.back()]:
		outer.append(f.node.basis * f.along)
	return outer[0].angle_to(outer[1])
