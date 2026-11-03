class_name BakedMotion
extends Node
## Figures played from baked clips instead of posed in code every frame: the crowd (people, animals), not the hero.
## A CharacterRig with `baked = true` whose clips exist (an AnimationLibrary made by tools/bake_motion.gd, at
## res://anims/<model>.res or set as `motion`) is handed over here: its own _process stops, and one manager advances
## every baked figure's AnimationPlayer by hand (callback mode manual), in tiers by distance from the camera:
##
##   the NEAREST few        every frame
##   within HALF_RATE m     every 2nd frame
##   further                every 3rd frame (about 20 Hz at 60)
##   out of sight           every OFF_SCREEN_EVERY frames (Godot does not cull skeletons; its shadow may still show)
##   past PAUSED_PAST m     not at all
##
## Clips: "idle" (standing), "idle_up" (an all-fours figure sat up), "air", and "move0".."moveN": one stride cycle
## each, at the speeds in the library's meta "speeds", all one second long (a second is one cycle), so a change of
## gait keeps the feet where they were in the stride. Played at the cycle rate its speed wants. "fours_move0".. for a
## figure that stands but goes on all fours (always_on_fours); "sprint_move0".. while its body is_sprinting. A body with `func baked_state() -> String` names
## what it is doing: a clip of that name (baked from the maker's bake_states), "live" to be posed live (climbing...),
## or "" to go by its speed.
## Live on top, only within NEAR m of the camera: the head turned to what the figure would look at (CharacterRig's
## _notice), and whatever the rig's _pose_baked() lays over (a porcupine's quills). Gone limp, a figure is posed live
## (its ragdoll) until it recovers.
## Next step for flocks of many small things (crows, fish): vertex-animation textures on a MultiMesh (not built).
##
##   rig.baked = true      # before it enters the tree; nothing more (no clips: it stays live)

const NEAREST := 8
const HALF_RATE := 25.0
const OFF_SCREEN_EVERY := 12
const PAUSED_PAST := 110.0
const NEAR := 12.0
## Crossfade between clips (s).
const BLEND := 0.22
const BLEND_STATE := 0.6
## Below this (m/s, as if at the size it was baked) it stands.
const STILL := 0.15

static var _libraries := {}
## Off: every figure posed live, as before (for measuring against: BAKED_MOTION_OFF set in the environment).
static var enabled := OS.get_environment("BAKED_MOTION_OFF") == ""
## Every figure stepped every frame, however far or out of sight (a test measuring motion frame by frame).
static var full_rate := false

var _figures: Array[Played] = []


class Played:
	var rig: CharacterRig
	var player: AnimationPlayer
	var library: AnimationLibrary
	var speeds: PackedFloat32Array
	var rates: PackedFloat32Array
	var fours_rates: PackedFloat32Array
	var sprint_rates: PackedFloat32Array
	var bake_scale := 1.0
	var bake_run := 0.0
	var sized := false
	var was_state := false
	var clip := &""
	var wait := 0
	var waited := 0.0
	var head := -1
	var look_yaw := 0.0
	var look_pitch := 0.0
	var notice_in := 0.0

	func step(delta: float, near: bool) -> void:
		var body := rig.get_parent()
		if not sized:
			_size_bones()
		# (what it is doing, if the body says: a state baked as its own clip, or "live" to be posed live)
		var state := String(body.call(&"baked_state")) if body.has_method(&"baked_state") else ""
		if state == "live":
			rig._process(delta)
			clip = &""
			return
		var velocity: Vector3 = body.get(&"velocity") if &"velocity" in body else Vector3.ZERO
		var size := maxf(rig.global_basis.get_scale().y, 0.01)
		var actual := Vector2(velocity.x, velocity.z).length()
		# (its gait chosen as the baked figure's at the same share of its run: a kit runs at its own run speed)
		var speed := actual * bake_scale / size
		if bake_run > 0.0 and &"run_speed" in body and float(body.get(&"run_speed")) > 0.0:
			speed = actual * bake_run / float(body.get(&"run_speed"))
		var grounded := true
		if body is CharacterBody3D:
			grounded = (body as CharacterBody3D).is_on_floor() or (&"air_time" in body and float(body.get(&"air_time")) < 0.1)
		var want := &"idle"
		var rate := 1.0
		# (as the live rig: on all fours sprinting, too)
		var fours: bool = (rig.always_on_fours or &"is_sprinting" in body and body.get(&"is_sprinting")) and not fours_rates.is_empty()
		if state != "" and library.has_animation(state):
			want = StringName(state)
		elif not grounded and library.has_animation(&"air"):
			want = &"air"
		elif speed < STILL or speeds.is_empty():
			if not rig.always_on_fours and library.has_animation(&"idle_up"):
				want = &"idle_up"
			elif rig.always_on_fours and library.has_animation(&"fours_idle"):
				want = &"fours_idle"
		else:
			var best := 0
			for i in speeds.size():
				if absf(speeds[i] - speed) < absf(speeds[best] - speed):
					best = i
			var sprinting: bool = &"is_sprinting" in body and body.get(&"is_sprinting") and not sprint_rates.is_empty()
			var prefix := "sprint_" if sprinting else "fours_" if fours else ""
			want = StringName("%smove%d" % [prefix, best])
			# (that clip's own stride, at its size, over the ground it covers: the feet stay put)
			var r := sprint_rates if sprinting else fours_rates if fours else rates
			rate = actual * r[best] / speeds[best] * bake_scale / size
		if want != clip:
			var moving := String(clip).contains("move") and String(want).contains("move")
			var at := player.current_animation_position if moving else 0.0
			# (into or out of a state, as sitting down, more slowly)
			player.play(want, BLEND_STATE if state != "" or was_state else BLEND)
			if moving:
				player.seek(at)
			clip = want
			was_state = state != ""
		player.speed_scale = rate
		player.advance(delta)
		if near:
			_look(delta)
		rig._pose_baked(delta, near)

	## A bone made bigger or smaller (a rest of its own: a build, a fat one) is so in every pose, as CharacterRig
	## poses it; the clips leave such bones' sizes alone.
	func _size_bones() -> void:
		sized = true
		var skeleton := rig._skeleton
		for b in skeleton.get_bone_count():
			var size := skeleton.get_bone_rest(b).basis.get_scale()
			if not size.is_equal_approx(Vector3.ONE):
				skeleton.set_bone_pose_scale(b, size)

	## The head turned to what it would look at (a pursuer close by...), over the clip's own head.
	func _look(delta: float) -> void:
		if head < 0:
			return
		notice_in -= delta
		if notice_in <= 0.0:
			notice_in = 0.2
			rig._notice()
		var yaw := 0.0
		var pitch := 0.0
		var thing: Node3D = rig._interest
		if is_instance_valid(thing):
			var to := thing.global_position - rig.global_position
			var ahead := rig.global_basis.z
			yaw = clampf(angle_difference(atan2(ahead.x, ahead.z), atan2(to.x, to.z)), -1.3, 1.3)
			pitch = clampf(-atan2(to.y - 0.3, Vector2(to.x, to.z).length()), -0.5, 0.5)
		look_yaw = lerpf(look_yaw, yaw, 1.0 - exp(-8.0 * delta))
		look_pitch = lerpf(look_pitch, pitch, 1.0 - exp(-8.0 * delta))
		if absf(look_yaw) < 0.01 and absf(look_pitch) < 0.01:
			return
		var skeleton := rig._skeleton
		var up := (skeleton.global_basis.inverse() * Vector3.UP).normalized()
		var side := (skeleton.global_basis.inverse() * rig.global_basis.x).normalized()
		var g := skeleton.get_bone_global_pose(head)
		var turned := Basis(up, look_yaw) * Basis(side, look_pitch) * g.basis
		var parent := skeleton.get_bone_parent(head)
		var above := skeleton.get_bone_global_pose(parent).basis if parent >= 0 else Basis.IDENTITY
		skeleton.set_bone_pose_rotation(head, (above.inverse() * turned).get_rotation_quaternion())


## The clips for `rig`, if any were baked: its `motion`, or res://anims/<its model's name>.res.
static func library_for(rig: CharacterRig) -> AnimationLibrary:
	if rig.motion:
		return rig.motion
	var name := rig.model.resource_path.get_file().get_basename() if rig.model else "boy"
	var path := "res://anims/%s.res" % name
	if not _libraries.has(path):
		_libraries[path] = load(path) if ResourceLoader.exists(path) else null
	return _libraries[path]


## Hands `rig` over to be played from its clips (CharacterRig does this when `baked`); false if it has none.
static func take(rig: CharacterRig) -> bool:
	var library := library_for(rig) if enabled else null
	if library == null or rig._skeleton == null:
		return false
	var player := AnimationPlayer.new()
	player.name = "Baked"
	rig.add_child(player)
	player.root_node = player.get_path_to(rig)
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	player.add_animation_library(&"", library)
	var figure := Played.new()
	figure.rig = rig
	figure.player = player
	figure.library = library
	figure.speeds = library.get_meta(&"speeds", PackedFloat32Array())
	figure.rates = library.get_meta(&"rates", PackedFloat32Array())
	figure.fours_rates = library.get_meta(&"fours_rates", PackedFloat32Array())
	figure.sprint_rates = library.get_meta(&"sprint_rates", PackedFloat32Array())
	figure.bake_scale = library.get_meta(&"bake_scale", 1.0)
	figure.bake_run = library.get_meta(&"bake_run", 0.0)
	figure.head = rig._skeleton.find_bone(&"head")
	figure.wait = randi() % 3
	player.play(&"idle")
	player.seek(randf() * player.current_animation_length)
	player.advance(0.0)
	rig.set_process(false)
	rig.watch_screen(OFF_SCREEN_EVERY)
	_manager(rig)._figures.append(figure)
	return true


static func _manager(rig: Node) -> BakedMotion:
	var tree := rig.get_tree()
	var found: BakedMotion = tree.root.get_meta(&"baked_motion") if tree.root.has_meta(&"baked_motion") else null
	if found == null or not is_instance_valid(found):
		found = BakedMotion.new()
		found.name = "BakedMotion"
		found.process_priority = 100
		tree.root.add_child.call_deferred(found)
		tree.root.set_meta(&"baked_motion", found)
	return found


## How many figures are played from clips now (for tests).
static func count(tree: SceneTree) -> int:
	var manager: BakedMotion = tree.root.get_meta(&"baked_motion") if tree.root.has_meta(&"baked_motion") else null
	return manager._figures.size() if manager else 0


func _process(delta: float) -> void:
	_figures = _figures.filter(func(f: Played) -> bool: return is_instance_valid(f.rig))
	var camera := get_viewport().get_camera_3d()
	var eye := camera.global_position if camera else Vector3.ZERO
	# (the nearest few in sight every frame: who they are)
	var near_ones := []
	for f in _figures:
		f.waited += delta
		var rig := f.rig
		if not rig.is_visible_in_tree() or not rig.can_process():
			continue
		if rig._ragdoll:
			# (gone limp: posed live, its ragdoll followed)
			rig._process(delta)
			f.waited = 0.0
			continue
		var far := eye.distance_to(rig.global_position) / clampf(rig.global_basis.get_scale().y, 0.3, 1.0)
		if far > PAUSED_PAST:
			f.waited = minf(f.waited, 0.5)
			continue
		var seen := rig._on_screen == null or rig._on_screen.is_on_screen() or DisplayServer.get_name() == "headless"
		var every := 3
		if full_rate:
			every = 1
		elif not seen:
			every = OFF_SCREEN_EVERY
		elif far <= HALF_RATE:
			near_ones.append([far, f])
			continue
		f.wait += 1
		if f.wait >= every:
			f.wait = 0
			f.step(minf(f.waited, 0.25), false)
			f.waited = 0.0
	near_ones.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	for k in near_ones.size():
		var f: Played = near_ones[k][1]
		f.wait += 1
		if k < NEAREST or f.wait >= 2:
			f.wait = 0
			f.step(minf(f.waited, 0.25), near_ones[k][0] < NEAR)
			f.waited = 0.0
