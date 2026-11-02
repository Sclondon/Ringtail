class_name CritterRig
extends CatRig
## The fox, the skunk, the badger and the rabbit (tools/build_critters.py) on the cat's rig: the raccoon's all-fours
## pose, bound, leap and spring tail, always on all fours, each with its own tail carriage. The rabbit's nose
## twitches. Their part in the game is not decided yet (2026-11-01).

const KINDS := ["fox", "skunk", "badger", "rabbit"]

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
}

var kind := "fox"
var _nose: Node3D
var _nose_rest := Vector3.ZERO
var _twitch := 0.0
var _twitch_wait := 1.0


## A rig for one of KINDS, to add to its body.
static func make(what: String) -> CritterRig:
	var rig := CritterRig.new()
	rig.kind = what
	rig.model = load("res://models/%s.glb" % what)
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


func _pose_extra(delta: float) -> void:
	super(delta)
	if _nose:
		# Twitching in little bursts, now and then
		_twitch_wait -= delta
		if _twitch_wait <= 0.0:
			_twitch = 0.6
			_twitch_wait = randf_range(0.8, 2.5)
		_twitch = maxf(_twitch - delta, 0.0)
		_nose.position = _nose_rest + Vector3(0.0, sin(_time * 55.0) * 0.004, sin(_time * 55.0 + 1.0) * 0.002) * smoothstep(0.0, 0.15, _twitch)
