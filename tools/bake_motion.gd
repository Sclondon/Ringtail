extends SceneTree
## Bakes a figure's code-posed motion (CharacterRig and the rigs on it) into clips that BakedMotion plays: it sets the
## figure down on a flat floor, drives it at fixed speeds with its own thinking switched off, and records every bone's
## pose each frame as tracks. One AnimationLibrary per model, at res://anims/<model name>.res:
##   idle, idle_up (an all-fours figure sat up), air, move0..moveN (one stride cycle each, one second long), and for
##   a figure that stands, fours_idle and fours_move0..N (the same on all fours); sprint_move0..N for a body with
##   is_sprinting (set at every speed); and any states the maker names
## with meta "speeds" (m/s), "rates", "fours_rates" and "sprint_rates" (cycles a second at each), "bake_scale" (its size baked) and
## "bake_run" (its body's run_speed).
## Each loop's end is blended into its start (no jump at the seam).
##
##   godot --headless --path . --audio-driver Dummy --fixed-fps 60 -s res://tools/bake_motion.gd -- \
##       <maker.gd> <what> [<what>...]
##
## <maker.gd> has `static func make(what) -> Node3D`: a body (CharacterBody3D) with its rig as `rig` or a child, the
## body's walk_speed and run_speed giving the speeds baked (half walk, walk, between, run, half again run; times its
## size, under a full-size figure). It may also have:
##   static func bake_states(what) -> Dictionary     # clip -> {"body": {property: value}, "rig": {property: value}}:
##                                                   # each held still and baked as a loop (sitting, talking...)
##   static func bake_drive(body, speed, state, delta) -> void   # each step, what its own thinking would set (at
##                                                   # that speed, in that state: "" moving or standing)
## The body's own thinking is switched off (process_mode disabled; the rig kept running).

## How long it settles at each speed before recording (s), and how much of the start each loop's end is blended over.
const SETTLE := 2.5
const SEAM_MOVE := 0.2
const SEAM_IDLE := 1.0
## Idle: two of a figure's breaths at rest (CharacterRig breathes at 1.5 radians a second standing).
const IDLE_LENGTH := 2.0 * TAU / 1.5

var _body: CharacterBody3D
var _rig: CharacterRig
var _skeleton: Skeleton3D
var _speed := 0.0
var _falling := false
var _frames: Array = []
var _recording := false
var _clock := 0.0
var _maker: Script
var _state := ""
var _sprinting := false


class Hook:
	extends Node
	var on_step: Callable
	func _physics_process(delta: float) -> void:
		if on_step.is_valid():
			on_step.call(delta)


class Tap:
	extends Node
	var on_frame: Callable
	func _process(delta: float) -> void:
		on_frame.call(delta)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2:
		push_error("bake_motion: <maker.gd> <what> [<what>...]")
		quit(1)
		return
	var maker: Script = load(args[0])
	var floor := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(800.0, 1.0, 800.0)
	shape.shape = box
	floor.add_child(shape)
	floor.position.y = -0.5
	root.add_child(floor)
	var camera := Camera3D.new()
	camera.position = Vector3(0.0, 2.0, -6.0)
	root.add_child(camera)
	var hook := Hook.new()
	hook.process_priority = -100
	hook.on_step = _drive
	root.add_child(hook)
	var tap := Tap.new()
	tap.process_priority = 100
	tap.on_frame = _record
	root.add_child(tap)
	DirAccess.make_dir_recursive_absolute("res://anims")
	for what in args.slice(1):
		await _bake(maker, what)
	quit()


func _drive(delta: float) -> void:
	if _body == null:
		return
	var fall := _body.velocity.y - 20.0 * delta if _falling else -0.1
	_body.velocity = Vector3(0.0, fall, _speed)
	_body.move_and_slide()
	if _maker.has_method(&"bake_drive"):
		_maker.call(&"bake_drive", _body, _speed, _state, delta)
	if _sprinting:
		_body.set(&"is_sprinting", true)
	if &"air_time" in _body:
		_body.set(&"air_time", 0.0 if _body.is_on_floor() else float(_body.get(&"air_time")) + delta)
	camera_follow()


func camera_follow() -> void:
	var camera := root.get_viewport().get_camera_3d()
	if camera:
		camera.global_position = _body.global_position + Vector3(0.0, 2.0, -6.0)


func _record(delta: float) -> void:
	if not _recording or _skeleton == null:
		return
	_clock += delta
	var count := _skeleton.get_bone_count()
	var at := PackedVector3Array()
	var turn: Array[Quaternion] = []
	var size := PackedVector3Array()
	for b in count:
		at.append(_skeleton.get_bone_pose_position(b))
		turn.append(_skeleton.get_bone_pose_rotation(b))
		size.append(_skeleton.get_bone_pose_scale(b))
	_frames.append([_clock, float(_rig.get(&"_phase")), at, turn, size])


func _wait(seconds: float) -> void:
	var frames := int(seconds * 60.0)
	for _i in frames:
		await process_frame


func _bake(maker: Script, what: String) -> void:
	_body = maker.call(&"make", what)
	# (posed live, to be recorded)
	var made_rig: Variant = _body.get(&"rig")
	if made_rig is CharacterRig:
		(made_rig as CharacterRig).baked = false
	for child in _body.get_children():
		if child is CharacterRig:
			(child as CharacterRig).baked = false
	_maker = maker
	_rig = made_rig as CharacterRig
	# (its own thinking off; the rig, made but not yet a child till the body is ready, kept running)
	_body.process_mode = Node.PROCESS_MODE_DISABLED
	# (and kept in the physics, to be moved by hand)
	if _body is CollisionObject3D:
		(_body as CollisionObject3D).disable_mode = CollisionObject3D.DISABLE_MODE_KEEP_ACTIVE
	if _rig:
		_rig.process_mode = Node.PROCESS_MODE_ALWAYS
	root.add_child(_body)
	await process_frame
	await process_frame
	if _rig == null:
		for child in _body.get_children():
			if child is CharacterRig:
				_rig = child
				_rig.process_mode = Node.PROCESS_MODE_ALWAYS
	_skeleton = _rig._skeleton
	var library := AnimationLibrary.new()
	var walk: float = _body.get(&"walk_speed") if &"walk_speed" in _body else 1.4
	var run: float = _body.get(&"run_speed") if &"run_speed" in _body else 4.0
	# (a small figure is baked slower: its strides are short, and flat out it would turn over a stride in a few frames)
	var small := clampf(_rig.global_basis.get_scale().y, 0.3, 1.0)
	var speeds := PackedFloat32Array([walk * 0.5 * small, walk * small, (walk + run) * 0.5 * small, run * small, run * 1.5 * small])
	# Standing (and sat up, for one on all fours)
	await _still(library, &"idle")
	if _rig.always_on_fours:
		_rig.always_on_fours = false
		await _still(library, &"idle_up")
		_rig.always_on_fours = true
	else:
		_rig.always_on_fours = true
		await _still(library, &"fours_idle")
		_rig.always_on_fours = false
	var rates := await _moves(library, speeds, "")
	library.set_meta(&"rates", rates)
	if not _rig.always_on_fours:
		_rig.always_on_fours = true
		library.set_meta(&"fours_rates", await _moves(library, speeds, "fours_"))
		_rig.always_on_fours = false
	# Sprinting at every speed, for a body that sprints (a kit sprints at a walk)
	if &"is_sprinting" in _body:
		_sprinting = true
		library.set_meta(&"sprint_rates", await _moves(library, speeds, "sprint_"))
		_sprinting = false
		_body.set(&"is_sprinting", false)
	# The states the maker names, each held still
	var states: Dictionary = _maker.call(&"bake_states", what) if _maker.has_method(&"bake_states") else {}
	for state: String in states:
		var sets: Dictionary = states[state]
		var was := {}
		for part: String in ["body", "rig"]:
			var target: Object = _body if part == "body" else _rig
			for key: String in sets.get(part, {}):
				was[[part, key]] = target.get(key)
				target.set(key, sets[part][key])
		_state = state
		await _still(library, StringName(state))
		_state = ""
		for k: Array in was:
			(_body if k[0] == "body" else _rig).set(k[1], was[k])
	_speed = 0.0
	# In the air: falling from high over the floor
	_place(Vector3(0.0, 40.0, 300.0))
	_falling = true
	await _wait(0.3)
	_start()
	await _wait(0.6 + 0.2)
	_recording = false
	_falling = false
	library.add_animation(&"air", _clip(0.6, 0.2))
	library.set_meta(&"speeds", speeds)
	library.set_meta(&"bake_scale", _rig.global_basis.get_scale().y)
	library.set_meta(&"bake_run", run)
	var name := _rig.model.resource_path.get_file().get_basename() if _rig.model else what
	var path := "res://anims/%s.res" % name
	var made := ResourceSaver.save(library, path, ResourceSaver.FLAG_COMPRESS)
	print("BAKED %s -> %s (%s)  %d clips  speeds %s  rates %s" % [what, path, error_string(made), library.get_animation_list().size(), speeds, rates])
	_body.queue_free()
	_body = null
	await process_frame


## Each speed: one stride, from the phase coming round to 0 to its coming round again. Its cycles a second at each.
func _moves(library: AnimationLibrary, speeds: PackedFloat32Array, prefix: String) -> PackedFloat32Array:
	var rates := PackedFloat32Array()
	for i in speeds.size():
		_place(Vector3(0.0, 0.05, -300.0))
		_speed = speeds[i]
		await _wait(SETTLE)
		print("BAKING %smove%d at %.2f m/s" % [prefix, i, _speed])
		# (a figure whose stride never comes round, as one stuck, is given up on after 10 s)
		var last := float(_rig.get(&"_phase"))
		var frames := 0
		while frames < 600:
			await process_frame
			frames += 1
			var now := float(_rig.get(&"_phase"))
			if now < last - 0.5:
				break
			last = now
		_start()
		var turns := 0
		last = float(_rig.get(&"_phase"))
		while frames < 1200:
			await process_frame
			frames += 1
			var now := float(_rig.get(&"_phase"))
			if now < last - 0.5:
				turns += 1
			last = now
			if turns + now >= 1.0 + SEAM_MOVE:
				break
		if frames >= 1200:
			push_error("bake_motion: %smove%d: its stride never came round (phase %.2f)" % [prefix, i, last])
		_recording = false
		# (time in phase, unwrapped)
		var wraps := 0
		var before := 0.0
		for frame: Array in _frames:
			var p: float = frame[1]
			if p < before - 0.5:
				wraps += 1
			before = p
			frame[0] = wraps + p - float(_frames[0][1])
		# (cycles a second: one cycle over the time it took)
		var span: float = 0.0
		for frame_i in _frames.size():
			if float(_frames[frame_i][0]) >= 1.0:
				span = (frame_i) / 60.0
				break
		rates.append(1.0 / maxf(span, 0.05))
		library.add_animation(StringName("%smove%d" % [prefix, i]), _clip(1.0, SEAM_MOVE))
	_speed = 0.0
	return rates


func _place(at: Vector3) -> void:
	_body.global_position = at
	_body.velocity = Vector3.ZERO


func _start() -> void:
	_frames.clear()
	_clock = 0.0
	_recording = true


func _still(library: AnimationLibrary, called: StringName) -> void:
	print("BAKING %s" % called)
	_place(Vector3(20.0, 0.05, 0.0))
	_speed = 0.0
	await _wait(SETTLE)
	_start()
	await _wait(IDLE_LENGTH + SEAM_IDLE)
	_recording = false
	library.add_animation(called, _clip(IDLE_LENGTH, SEAM_IDLE))


## The frames recorded (time in their [0]) made a loop `length` long: the first `seam` of it blended from what came
## after the end into what came at the start, so the end runs on into the start.
func _clip(length: float, seam: float) -> Animation:
	var clip := Animation.new()
	clip.length = 1.0 if length == 1.0 else length
	clip.loop_mode = Animation.LOOP_LINEAR
	var t0: float = _frames[0][0]
	var keys: Array = []
	for frame: Array in _frames:
		var t: float = float(frame[0]) - t0
		if t >= length:
			break
		var poses: Array = [frame[2], frame[3], frame[4]]
		if t < seam:
			var after := _at(t + length + t0)
			var w := t / seam
			var at := PackedVector3Array()
			var turn: Array[Quaternion] = []
			var size := PackedVector3Array()
			for b in (frame[2] as PackedVector3Array).size():
				at.append((after[2][b] as Vector3).lerp(frame[2][b], w))
				turn.append((after[3][b] as Quaternion).slerp(frame[3][b], w))
				size.append((after[4][b] as Vector3).lerp(frame[4][b], w))
			poses = [at, turn, size]
		keys.append([t, poses])
	var base := String(_rig.get_path_to(_skeleton))
	for b in _skeleton.get_bone_count():
		var path := NodePath("%s:%s" % [base, _skeleton.get_bone_name(b)])
		for kind in 3:
			var first: Variant = keys[0][1][kind][b]
			var still := true
			for key: Array in keys:
				var v: Variant = key[1][kind][b]
				if kind == 1:
					if absf((v as Quaternion).dot(first)) < 0.999999:
						still = false
						break
				elif not (v as Vector3).is_equal_approx(first):
					still = false
					break
			if kind == 2 and still and (first as Vector3).is_equal_approx(Vector3.ONE):
				continue
			var track := clip.add_track([Animation.TYPE_POSITION_3D, Animation.TYPE_ROTATION_3D, Animation.TYPE_SCALE_3D][kind])
			clip.track_set_path(track, path)
			for key: Array in (keys.slice(0, 1) if still else keys):
				var t: float = key[0] / length * clip.length
				match kind:
					0: clip.position_track_insert_key(track, t, key[1][0][b])
					1: clip.rotation_track_insert_key(track, t, key[1][1][b])
					2: clip.scale_track_insert_key(track, t, key[1][2][b])
	return clip


## The recorded frame nearest time `t`.
func _at(t: float) -> Array:
	var best: Array = _frames[0]
	for frame: Array in _frames:
		if absf(float(frame[0]) - t) < absf(float(best[0]) - t):
			best = frame
	return best
