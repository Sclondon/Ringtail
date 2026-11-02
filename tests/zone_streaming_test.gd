extends SceneTree
## Only the zone he is in runs (ZoneStreaming): he is set down in the grove, in each side's middle and back in the
## grove; at each, what is home in his zone is live, a still thing in a zone next to his frozen (shown, not running),
## what is in the zone across from his hidden and out of the physics, his band never paused, and the HUD names his
## zone with that zone's counts, the hill's food total unchanged. Headless:
##   godot --headless --path . --audio-driver Dummy --fixed-fps 60 -s res://tests/zone_streaming_test.gd

var failures: Array[String] = []
var world: World


func _initialize() -> void:
	world = (load("res://scenes/world1.tscn") as PackedScene).instantiate()
	root.add_child(world)
	_run.call_deferred()


func _check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)
	if not ok:
		failures.append(what)


func _ground(at: Vector3) -> Vector3:
	var hit := world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(at + Vector3.UP * 60.0, at + Vector3.DOWN * 80.0, 1))
	return (hit.position as Vector3) if not hit.is_empty() else at


## A thing home in `zone` (a creature: and in it now), beyond the live reach of `him` (null if none).
func _one(streaming: ZoneStreaming, zone: int, him: Vector3, still: bool) -> Node3D:
	for thing: Array in streaming._things:
		if not is_instance_valid(thing[0]):
			continue
		var node: Node = thing[0]
		if thing[1] == zone and thing[2] == still and not (node is Villager and (node as Villager).leader):
			var at := streaming._where(node)
			if not still and streaming.zones.zone_of(at) != zone:
				continue
			if Vector2(at.x - him.x, at.z - him.z).length() > ZoneStreaming.LIVE_REACH + 5.0:
				return node
	return null


func _run() -> void:
	for _i in 30:
		await physics_frame
	var zones := world.zones
	var streaming := world.get_node_or_null(^"ZoneStreaming") as ZoneStreaming
	_check(streaming != null and zones != null and zones.names.size() == 5, "streaming runs over five zones")
	if streaming == null:
		_end()
		return
	var total := 0
	for k in zones.names.size():
		total += zones.food_total[k]
	var spots := [[zones.grove, world.player.global_position]]
	for name: String in world.markers:
		if name.begins_with("zone_"):
			var at := _ground((world.markers[name] as Transform3D).origin)
			spots.append([zones.zone_of(at), at])
	spots.append(spots[0])
	var sides := zones.grove
	for spot: Array in spots:
		var here: int = spot[0]
		var him: Vector3 = spot[1]
		world.player.global_position = him + Vector3.UP * 0.5
		world.player.velocity = Vector3.ZERO
		# (a whole pass over everything, a few at a time, and a look again)
		for _i in streaming._things.size() / ZoneStreaming.PER_FRAME + 40:
			await process_frame
		var name: String = zones.names[here]
		_check(zones.current == here, "%s: he is in it" % name)
		var label := "The grove" if here == zones.grove else name
		_check(world.hud._zone.text == label, "%s: the HUD says %s (%s)" % [name, label, world.hud._zone.text])
		_check(world.hud._crumbs.text == "%d / %d" % [zones.food[here], zones.food_total[here]], "%s: the HUD counts its food (%s)" % [name, world.hud._crumbs.text])
		var mine := _one(streaming, here, him, true)
		_check(mine != null and streaming.state_of(mine) == ZoneStreaming.State.LIVE and mine.can_process() and mine.is_visible_in_tree(), "%s: its own things live" % name)
		var mover := _one(streaming, here, him, false)
		if mover:
			_check(streaming.state_of(mover) == ZoneStreaming.State.LIVE and mover.can_process(), "%s: its own creatures live (%s)" % [name, mover.name])
		if here == zones.grove:
			# (from the grove every side is next door: their still things shown, their creatures hidden)
			for k in sides:
				var still := _one(streaming, k, him, true)
				_check(still != null and streaming.state_of(still) == ZoneStreaming.State.FROZEN and not still.can_process() and still.is_visible_in_tree(), "Grove: %s's things frozen" % zones.names[k])
				var beast := _one(streaming, k, him, false)
				if beast:
					_check(streaming.state_of(beast) == ZoneStreaming.State.HIDDEN and not beast.can_process() and not beast.visible, "Grove: %s's creatures hidden (%s)" % [zones.names[k], beast.name])
		else:
			var next := _one(streaming, (here + 1) % sides, him, true)
			_check(next != null and streaming.state_of(next) == ZoneStreaming.State.FROZEN and next.visible and not next.can_process(), "%s: the side next door frozen" % name)
			var across := _one(streaming, (here + 2) % sides, him, true)
			_check(across != null and streaming.state_of(across) == ZoneStreaming.State.HIDDEN and not across.visible and not across.can_process(), "%s: the side across hidden" % name)
		# (his band follows him everywhere and is never paused)
		var band := world.find_children("*", "SquadRaccoon", true, false)
		_check(band.all(func(m: Node) -> bool: return m.can_process()), "%s: his band runs (%d)" % [name, band.size()])
		var now := 0
		for k in zones.names.size():
			now += zones.food_total[k]
		_check(now == total, "%s: the hill's food still %d" % [name, now])
	var live: Array = streaming.counts()
	print("live %d frozen %d hidden %d" % live)
	_end()


func _end() -> void:
	print("PASS" if failures.is_empty() else "FAILED %d: %s" % [failures.size(), ", ".join(failures)])
	quit(0 if failures.is_empty() else 1)
