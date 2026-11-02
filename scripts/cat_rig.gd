class_name CatRig
extends RaccoonRig
## The yard cat's rig: the raccoon's (all fours, the bound, the leap, the spring tail) on the cat's model,
## on all fours whenever it is on the ground, its tail carried up, and a rump wiggle before it pounces.

## How hard it is wiggling its rump (0..1), set by YardCat.
var wiggle := 0.0
## How far over it is tumbling (radians), knocked flying by his tail; set by YardCat.
var tumble := 0.0

## How far down its upper lids sit beyond his at rest (radians, about each eye).
const LID_REST := 0.6
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


## Up on its hind legs now and then, walking as he does, while no person is near (the user, 2026-11-02: "all
## animals that can should walk around on 2 feet sometimes too if people aren't around"). Not those that can't
## (NEVER_UPRIGHT), not when played, and never going faster than a walk. How often and how long are Claude's picks.
const NEVER_UPRIGHT := ["frog", "turtle"]
const PEOPLE_NEAR := 25.0
const UPRIGHT_SPEED := 1.3
var _upright := false
var _upright_for := randf_range(3.0, 12.0)
var _people_check := 0.0
var _people_near := false


func _choose_upright(delta: float) -> void:
	var body := get_parent() as CharacterBody3D
	if body == null or body is Player or (get(&"kind") in NEVER_UPRIGHT):
		return
	_upright_for -= delta
	if _upright_for <= 0.0:
		_upright = not _upright and randf() < 0.45
		_upright_for = randf_range(4.0, 10.0) if _upright else randf_range(6.0, 16.0)
	_people_check -= delta
	if _people_check <= 0.0:
		_people_check = 0.5
		_people_near = false
		for person: Node3D in get_tree().get_nodes_in_group(&"people"):
			if person.is_visible_in_tree() and person.global_position.distance_to(global_position) < PEOPLE_NEAR:
				_people_near = true
				break
	var slow := Vector2(body.velocity.x, body.velocity.z).length() < UPRIGHT_SPEED
	always_on_fours = not (_upright and slow and not _people_near and wiggle < 0.01 and absf(tumble) < 0.01)


func _pose_extra(delta: float) -> void:
	_choose_upright(delta)
	super(delta)
	# (its upper lids rest a little lowered over its eyes, not rolled right back as his are: wide open all round they
	# stared; the user, 2026-11-02, "the cat eyes need work they look creepy". A blink still closes them.)
	for lid in _lids:
		lid.basis = lid.basis * Basis(Vector3.RIGHT, LID_REST)
	if wiggle > 0.001:
		# (its rump sways side to side, quick, and the tip of its tail flicks)
		_hips.basis = Basis(Vector3.UP, sin(_time * 24.0) * 0.16 * wiggle) * _hips.basis
	if absf(tumble) > 0.001:
		_hips.basis = Basis(Vector3.RIGHT, tumble) * _hips.basis
		_hips.position.y += 0.15 * absf(sin(tumble))
