extends RefCounted
## The raccoons for tools/bake_motion.gd: a grown-up villager on RaccoonRig (models/raccoon.glb, which the kits and
## the squad share), and the states Villager.baked_state() and SquadRaccoon.baked_state() name.
##   godot --headless --path . --audio-driver Dummy --fixed-fps 60 -s res://tools/bake_motion.gd -- \
##       res://tools/bake_raccoons.gd raccoon


static func make(_what: String) -> Node3D:
	var body := Villager.new()
	var rig := RaccoonRig.new()
	rig.name = "Rig"
	rig.dusty = false
	rig.key_poses = false
	rig.cap_hand = false
	body.rig = rig
	# (a villager picks on its own whether it stands; baked standing, and on all fours as well)
	body.ready.connect(func() -> void: rig.always_on_fours = false)
	return body


static func bake_states(_what: String) -> Dictionary:
	return {
		"sit": {"body": {"sit_progress": 1.0}},
		"groom": {"body": {"sit_progress": 1.0}},
		"nap": {"body": {"sit_progress": 1.0}},
		"sit_talk": {"body": {"sit_progress": 1.0}, "rig": {"talking": 1.0}},
		"sit_listen": {"body": {"sit_progress": 1.0}, "rig": {"listening": 1.0}},
		"lounge": {"body": {"sit_progress": 1.0}, "rig": {"lounge": 1.0}},
		"talk": {"rig": {"talking": 1.0}},
		"listen": {"rig": {"listening": 1.0}},
		"cheer": {"rig": {"cheer": 1.0}},
		"clap": {"rig": {"clap": 1.0}},
		"rummage": {"body": {"is_ducking": true}},
	}


static func bake_drive(body: Node3D, speed: float, state: String, delta: float) -> void:
	var villager := body as Villager
	# (as Villager: on all fours once it is going fast)
	villager.is_sprinting = speed > villager.run_speed * 0.7
	match state:
		"groom":
			# (a rub over its face every 2.4 s)
			villager.rub_progress = fmod(villager.rub_progress + delta / 2.4, 1.0)
		"nap":
			villager.rig.express(&"sleepy", 0.5)
