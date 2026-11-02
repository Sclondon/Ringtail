class_name CatRig
extends RaccoonRig
## The yard cat's rig: the raccoon's (all fours, the bound, the leap, the spring tail) on the cat's model,
## on all fours whenever it is on the ground, its tail carried up, and a rump wiggle before it pounces.

## How hard it is wiggling its rump (0..1), set by YardCat.
var wiggle := 0.0
## How far over it is tumbling (radians), knocked flying by his tail; set by YardCat.
var tumble := 0.0

# The cat's tail, as angles below straight back in its hips' space: carried up and curled over at the tip.
const CAT_STAND := [-0.9, -1.05, -1.1, -0.9, -0.35, 0.3]
const CAT_RUN := [-0.2, -0.3, -0.35, -0.3, -0.2, -0.1]
# (on all fours its hips are pitched well forward: these come out up and back, curling over)
const CAT_QUAD := [0.25, -0.05, -0.25, -0.15, 0.3, 0.8]


func _init() -> void:
	model = preload("res://models/cat.glb")
	always_on_fours = true
	tail_stand = CAT_STAND
	tail_run = CAT_RUN
	tail_quad = CAT_QUAD


func _pose_extra(delta: float) -> void:
	super(delta)
	if wiggle > 0.001:
		# (its rump sways side to side, quick, and the tip of its tail flicks)
		_hips.basis = Basis(Vector3.UP, sin(_time * 24.0) * 0.16 * wiggle) * _hips.basis
	if absf(tumble) > 0.001:
		_hips.basis = Basis(Vector3.RIGHT, tumble) * _hips.basis
		_hips.position.y += 0.15 * absf(sin(tumble))
