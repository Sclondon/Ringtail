class_name CarRider
extends Figure
## Someone in a vehicle (the user, 2026-11-02: "there should be people in the cars"): one of the town's people (the
## low boy, models/boy_tp.glb, dressed by CharacterLook in a HeadShape mask head, as HazardPerson), sat on one of its
## seats (the model's `<kind>_seat_<n>` empties: build_vehicles.py cabin()). The driver's hands are on the wheel (its
## `_grip_l`/`_grip_r`); anyone else's in their lap. Every so often each turns their head to look out a while.
##
## It is no body: nothing runs into it, it never falls; HazardCar sets where it sits each frame (`sit`) and its pose
## is laid over the rig's standing still (SeatedRig). Far from the camera it is posed less often, and further still
## not at all (HazardCar: `far`), then not drawn.

## How tall, as the boy's figure (Claude's pick: a little under the walkers' 1.4, about 1.56 m, so they sit in a kei
## or a hatchback with room over their heads).
const RIDER_SIZE := 1.25

var look_seed := 1
var driver := false
## How high the floor is in the vehicle (m, from the ground): the feet go down to it.
var floor := 0.35
## How far forward of the hips the feet may go (m): the back of the seat in front (INF: none).
var legroom := INF
## The vehicle's model and the seat and grips in it (nodes of the model).
var seat: Node3D
var grips: Array[Node3D] = []


func _init() -> void:
	super()
	model = preload("res://models/boy_tp.glb")
	size = RIDER_SIZE
	dusty = false
	radius = 0.05
	height = 0.2


func _ready() -> void:
	collision_layer = 0
	collision_mask = 0
	super()
	set_physics_process(false)
	HeadShape.add_to(rig)
	var chosen := CharacterLook.random(look_seed)
	chosen["face"] = "mannequin"
	var dressed := CharacterLook.dressed(chosen)
	var masks := ["mask", "mask_long", "mask_soft", "mask_brow", "mask_square", "inside"]
	dressed["parts"]["head"] = HeadShape.option(masks[look_seed % masks.size()])
	rig.look = dressed
	if rig.is_node_ready():
		rig.restyle()
	var seated := rig as SeatedRig
	seated.rider = self
	seated.glance_wait = randf_range(1.0, 6.0)


func _new_rig() -> CharacterRig:
	return SeatedRig.new()


func _physics_process(_delta: float) -> void:
	pass


func _process(_delta: float) -> void:
	sit()


## Puts the figure on its seat, wherever the vehicle is now.
func sit() -> void:
	if seat == null or rig == null:
		return
	var at := seat.global_transform.orthonormalized()
	rig.global_transform = Transform3D(at.basis.scaled(Vector3.ONE * size), at.origin)


## The rig sat: hips on the seat, leant back a little, thighs out along it, feet down on the floor; hands on the wheel
## or in the lap; the head turned now and then.
class SeatedRig extends CharacterRig:
	## How high the hip joints are over the seat (in the boy's own size), and how far back the body leans (rad).
	const SEAT_HIP := 0.085
	const SEAT_LEAN := 0.2
	## Where the feet go (the boy's size): apart, and forward of the hips; down on the floor, the ankle FOOT_LIFT over the floor.
	const SEAT_FOOT := Vector3(0.1, 0.0, 0.4)
	const FOOT_LIFT := 0.06

	var rider: CarRider
	var glance_wait := 3.0
	var _glance := 0.0
	var _glance_to := 0.0
	var _glance_hold := 0.0

	func _pose_extra(delta: float) -> void:
		if rider == null:
			return
		var hips_basis := Basis(Vector3.RIGHT, -SEAT_LEAN)
		_hips.transform = Transform3D(hips_basis, Vector3(0.0, SEAT_HIP, 0.0))
		# Legs: thighs out along the seat, shins down to the floor, feet flat on it
		var flat := hips_basis.inverse()
		for i in 2:
			var side := 1.0 if i == 0 else -1.0
			# (the floor under the seat, in the rig's own size: the seat is the rig's origin)
			var down := (rider.seat.position.y - rider.floor) / rider.size - FOOT_LIFT
			# (a high seat over the floor, as in a kei or a bus, has the feet nearer under it; a back seat, short of the
			# seat in front)
			var foot := Vector3(side * SEAT_FOOT.x, -down - SEAT_HIP, clampf(minf(SEAT_FOOT.z + 0.08 - down, (rider.legroom - 0.1) / rider.size), 0.2, SEAT_FOOT.z))
			_solve_leg(i, side, flat * foot, flat, 0.0)
		# Arms: on the wheel, or resting on the thighs
		for i in 2:
			var side := 1.0 if i == 0 else -1.0
			var point: Vector3
			if rider.driver and rider.grips.size() == 2:
				point = rider.grips[i].global_position
			else:
				point = to_global(_hips.transform * (flat * Vector3(side * 0.09, 0.02, 0.2)))
			var elbow_way := global_basis.orthonormalized() * Vector3(side * 0.7, -1.0, -0.2)
			_solve_arm(i, side, point, _forearm, 1.0, elbow_way.normalized())
		# Now and then a look out of the window (or at the road, for the driver: never far)
		glance_wait -= delta
		_glance_hold -= delta
		if glance_wait <= 0.0:
			var reach := 0.45 if rider.driver else 1.0
			_glance_to = randf_range(-reach, reach)
			_glance_hold = randf_range(1.0, 3.0)
			glance_wait = randf_range(3.0, 9.0)
		if _glance_hold <= 0.0:
			_glance_to = 0.0
		_glance = lerpf(_glance, _glance_to, 1.0 - exp(-3.0 * delta))
		_head.rotate_object_local(Vector3.UP, _glance)
