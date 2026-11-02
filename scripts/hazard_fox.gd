class_name HazardFox
extends Critter
## The fox (CritterRig "fox", built by tools/build_critters.py) as a ground predator living by its `den`: it prowls
## about the den; seeing the raccoon near, it gives chase on all fours, a little slower than he can run flat out, and
## bites if it catches him (it hurts); it gives up when he gets away, or after a while, and goes home. His tail spin
## sends it reeling, and it slinks off home. Claude's picks (placeholders): how near, how fast, how long.

enum State { PROWL, CHASE, BITE, DAZED, HOME }

var home := Vector3.ZERO
var player: Player
var notice := 8.0
var give_up := 14.0
var chase_time := 5.5
var chase_speed := 4.8

var mood := State.PROWL
var _state_t := 0.0
var _goal := Vector3.ZERO
var _rest := 0.0


static func spawn() -> HazardFox:
	var fox := HazardFox.new()
	fox.rig = CritterRig.make("fox")
	fox.rig.name = "Rig"
	fox.rig.scale = Vector3.ONE * Critter.SIZES["fox"]
	fox.rig.dusty = false
	fox.run_speed = 5.0
	return fox


func _ready() -> void:
	super()
	add_to_group(&"hazards")
	add_to_group(&"tail_hittable")
	_goal = home


func _go(to: State) -> void:
	mood = to
	_state_t = 0.0


func _physics_process(delta: float) -> void:
	_state_t += delta
	_rest = maxf(_rest - delta, 0.0)
	var near := global_position.distance_to(player.global_position) if player else INF
	var to_him := (player.global_position - global_position) if player else Vector3.ZERO
	to_him.y = 0.0
	match mood:
		State.PROWL:
			if global_position.distance_to(_goal) < 0.4 or _state_t > 5.0:
				_goal = home + Vector3(randf_range(-3.0, 3.0), 0.0, randf_range(-3.0, 3.0))
				_state_t = 0.0
			_drive_to(_goal, 0.9)
			if near < notice and _rest <= 0.0 and absf(to_him.length()) < notice and absf(player.global_position.y - global_position.y) < 1.5:
				_go(State.CHASE)
		State.CHASE:
			drive = to_him.normalized() * chase_speed
			if near < 0.65:
				drive = Vector3.ZERO
				Hazards.hurt(self, global_position)
				_go(State.BITE)
			elif near > give_up or _state_t > chase_time or absf(player.global_position.y - global_position.y) > 1.8:
				_rest = 4.0
				_go(State.HOME)
		State.BITE:
			# (a snap, then it backs off a moment before going again)
			drive = -to_him.normalized() * 1.5
			if _state_t > 0.8:
				_go(State.CHASE if near < notice else State.HOME)
		State.DAZED:
			drive = drive.move_toward(Vector3.ZERO, 6.0 * delta)
			if _state_t > 1.3:
				_rest = 6.0
				_go(State.HOME)
		State.HOME:
			_drive_to(home, 3.0)
			if global_position.distance_to(home) < 0.6:
				_go(State.PROWL)
	super(delta)


func _drive_to(point: Vector3, pace: float) -> void:
	var to := point - global_position
	to.y = 0.0
	drive = to.normalized() * pace if to.length() > 0.2 else Vector3.ZERO


## Hit by his tail: sent reeling, and off home.
func tail_hit(_from: Vector3, push: Vector3) -> void:
	if mood == State.DAZED:
		return
	drive = Vector3(push.x, 0.0, push.z) * 0.8
	velocity.y = 4.0
	_go(State.DAZED)
