class_name CritterRig
extends CatRig
## The fox, the skunk, the badger and the rabbit (tools/build_critters.py), and the grove's other animals (tools/
## build_grove_animals.py: beaver, rat, mouse, weasel, marten, otter, gopher, prairie dog, opossum, squirrel, porcupine,
## chipmunk) on the cat's rig: the raccoon's all-fours
## pose, bound, leap and spring tail, always on all fours, each with its own tail carriage. The rabbit's nose
## twitches. Their part in the game is not decided yet (2026-11-01).

const KINDS := ["fox", "skunk", "badger", "rabbit", "beaver", "rat", "mouse", "weasel", "marten", "otter", "gopher",
		"prairie_dog", "opossum", "squirrel", "porcupine", "chipmunk"]

## Tails, as each segment's angle below straight back in the hips' space: standing, running, and on all fours
## (where the hips are pitched well forward, so the same carriage takes larger numbers).
const TAILS := {
	# (out behind, brush low, the tip lifting)
	"fox": [[0.6, 0.35, 0.1, -0.05, -0.15, -0.2], [0.15, 0.05, 0.0, -0.05, -0.08, -0.1], [0.8, 0.75, 0.7, 0.6, 0.5, 0.4]],
	# (up over its back, the plume curling forward at the top)
	"skunk": [[-1.3, -1.45, -1.3, -0.8, -0.2, 0.4], [-1.0, -1.2, -1.1, -0.7, -0.2, 0.2], [-0.5, -0.65, -0.55, -0.15, 0.4, 0.95]],
	# (a stub, held out)
	"badger": [[0.4, 0.3, 0.2, 0.1, 0.1, 0.1], [0.2, 0.1, 0.1, 0.0, 0.0, 0.0], [0.7, 0.6, 0.5, 0.5, 0.5, 0.5]],
	# (a puff, tucked up)
	"rabbit": [[-0.6, -0.6, -0.6, -0.6, -0.6, -0.6], [-0.4, -0.4, -0.4, -0.4, -0.4, -0.4], [0.2, 0.2, 0.2, 0.2, 0.2, 0.2]],
	# (the paddle out behind, flat on the ground)
	"beaver": [[0.9, 0.9, 0.9, 0.9, 0.9, 0.9], [0.4, 0.3, 0.3, 0.3, 0.3, 0.3], [1.3, 1.3, 1.25, 1.2, 1.2, 1.2]],
	# (long and thin, trailing, the tip curling)
	"rat": [[0.9, 0.8, 0.6, 0.4, 0.2, 0.0], [0.4, 0.3, 0.2, 0.1, 0.0, -0.1], [1.2, 1.1, 1.0, 0.9, 0.8, 0.6]],
	"mouse": [[0.7, 0.6, 0.4, 0.2, 0.0, -0.2], [0.3, 0.2, 0.1, 0.0, -0.1, -0.2], [1.0, 0.9, 0.8, 0.6, 0.4, 0.2]],
	# (straight out behind, low)
	"weasel": [[0.5, 0.4, 0.3, 0.2, 0.2, 0.2], [0.2, 0.1, 0.1, 0.0, 0.0, 0.0], [0.9, 0.8, 0.7, 0.6, 0.6, 0.6]],
	"marten": [[0.7, 0.5, 0.3, 0.2, 0.1, 0.1], [0.3, 0.2, 0.1, 0.0, 0.0, 0.0], [1.0, 0.9, 0.8, 0.7, 0.6, 0.6]],
	# (thick, tapering out behind)
	"otter": [[1.0, 0.9, 0.8, 0.7, 0.6, 0.5], [0.4, 0.3, 0.2, 0.1, 0.1, 0.1], [1.3, 1.2, 1.1, 1.0, 0.9, 0.9]],
	"gopher": [[0.6, 0.6, 0.6, 0.6, 0.6, 0.6], [0.3, 0.3, 0.3, 0.3, 0.3, 0.3], [1.0, 1.0, 1.0, 1.0, 1.0, 1.0]],
	"prairie_dog": [[0.5, 0.5, 0.5, 0.5, 0.5, 0.5], [0.2, 0.2, 0.2, 0.2, 0.2, 0.2], [0.9, 0.9, 0.9, 0.9, 0.9, 0.9]],
	# (bare, hanging, curling at the tip)
	"opossum": [[0.8, 0.7, 0.6, 0.5, 0.2, -0.3], [0.4, 0.3, 0.2, 0.1, 0.0, -0.2], [1.1, 1.0, 0.9, 0.8, 0.5, 0.0]],
	# (curled up over its back, the plume curling forward at the top)
	"squirrel": [[-1.2, -1.4, -1.3, -0.9, -0.3, 0.3], [-0.6, -0.8, -0.7, -0.4, 0.0, 0.3], [-0.4, -0.6, -0.5, -0.2, 0.3, 0.8]],
	"chipmunk": [[-0.9, -1.0, -1.0, -0.9, -0.8, -0.7], [-0.3, -0.3, -0.3, -0.3, -0.3, -0.3], [0.0, -0.1, -0.1, -0.1, -0.1, -0.1]],
	"porcupine": [[0.6, 0.6, 0.6, 0.6, 0.6, 0.6], [0.4, 0.4, 0.4, 0.4, 0.4, 0.4], [1.0, 1.0, 1.0, 1.0, 1.0, 1.0]],
}

var kind := "fox"
## A porcupine's quills raised (0 laid flat .. 1 bristling): set from outside (GroveAnimals).
var bristle := 0.0
var _quill_bone := -1
var _quill_rest := Transform3D.IDENTITY
var _bristled := 0.0
var _nose: Node3D
var _nose_rest := Vector3.ZERO
var _twitch := 0.0
var _twitch_wait := 1.0


## A rig for one of KINDS, to add to its body.
static func make(what: String, low := false) -> CritterRig:
	var rig := CritterRig.new()
	rig.kind = what
	# (`low`: the light build, for the many in the grove)
	rig.model = load("res://models/%s%s.glb" % [what, "_lo" if low and ResourceLoader.exists("res://models/%s_lo.glb" % what) else ""])
	var tails: Array = TAILS[what]
	rig.tail_stand = tails[0]
	rig.tail_run = tails[1]
	rig.tail_quad = tails[2]
	rig.always_on_fours = true
	return rig


func _ready() -> void:
	super()
	if _has(&"nose"):
		_nose_rest = _rest(&"nose")
		_nose = _joint(_head, &"nose", _nose_rest)
	if _has(&"quills"):
		_quill_bone = _skeleton.find_bone(&"quills")
		_quill_rest = _skeleton.get_bone_rest(_quill_bone)


func _pose_extra(delta: float) -> void:
	super(delta)
	if _quill_bone >= 0:
		# (the quills raised: their bone's rest made bigger, which every pose keeps)
		_bristled = move_toward(_bristled, bristle, delta * 3.0)
		var grow := 1.0 + 0.45 * smoothstep(0.0, 1.0, _bristled)
		_skeleton.set_bone_rest(_quill_bone, Transform3D(_quill_rest.basis.scaled_local(Vector3(grow, grow, grow)), _quill_rest.origin))
	if _nose:
		# Twitching in little bursts, now and then
		_twitch_wait -= delta
		if _twitch_wait <= 0.0:
			_twitch = 0.6
			_twitch_wait = randf_range(0.8, 2.5)
		_twitch = maxf(_twitch - delta, 0.0)
		_nose.position = _nose_rest + Vector3(0.0, sin(_time * 55.0) * 0.004, sin(_time * 55.0 + 1.0) * 0.002) * smoothstep(0.0, 0.15, _twitch)
