class_name HazardPerson
extends Figure
## Someone out walking (GameCommon's Figure, the boy's figure grown to a grown-up's size, dressed by CharacterLook):
## they stroll a pavement path there and back. Seeing the raccoon near, they start, then come at him to stamp and
## shoo him off; a stamp that lands hurts him. They give up when he gets away, and go back to their walk. Claude's
## picks (placeholders): how near, how long they chase, the stamp. (`mood`, not `state`: the rig reads a body's `state`
## as the Player's.)

enum State { STROLL, START, CHASE, STAMP, BACK }

var route := PackedVector3Array()
## Where on the path they start, 0..1.
var start := 0.0
var look_seed := 1
var player: Player
var notice := 4.5
var give_up := 9.0
var chase_time := 4.5

var mood := State.STROLL
var _leg := 0
var _forward := true
var _state_t := 0.0
var _rest := 0.0


func _init() -> void:
	super()
	size = 1.4
	walk_speed = 1.2
	run_speed = 3.6
	dusty = false


func _ready() -> void:
	add_to_group(&"hazards")
	add_to_group(&"people")
	if route.size() >= 2:
		var at := clampf(start, 0.0, 0.999) * (route.size() - 1)
		_leg = int(at)
		position = route[_leg].lerp(route[_leg + 1], at - _leg)
	super()
	CharacterLook.apply(rig, CharacterLook.random(look_seed))
	_next()


func _go(to: State) -> void:
	mood = to
	_state_t = 0.0


func _next() -> void:
	if route.size() < 2:
		return
	if _forward:
		_leg += 1
		if _leg >= route.size():
			_leg = route.size() - 2
			_forward = false
	else:
		_leg -= 1
		if _leg < 0:
			_leg = 1
			_forward = true
	go_to(route[_leg])


func _physics_process(delta: float) -> void:
	_state_t += delta
	_rest = maxf(_rest - delta, 0.0)
	var near := INF
	if player:
		near = global_position.distance_to(player.global_position)
	match mood:
		State.STROLL:
			if not is_going():
				_next()
			if near < notice and _rest <= 0.0 and absf(player.global_position.y - global_position.y) < 1.5:
				stop()
				face(player.global_position)
				_go(State.START)
		State.START:
			# (a start: stopped dead, looking at him)
			face(player.global_position)
			on_the_spot = 0.0
			if _state_t > 0.6:
				_go(State.CHASE)
		State.CHASE:
			go_to(player.global_position, true)
			if near < 0.95:
				stop()
				_go(State.STAMP)
			elif near > give_up or _state_t > chase_time or absf(player.global_position.y - global_position.y) > 1.6:
				_back()
		State.STAMP:
			face(player.global_position)
			# (a stamp: the body drops, and lands on him if he is still there)
			stoop = 0.35 * sin(PI * clampf(_state_t / 0.45, 0.0, 1.0))
			if _state_t > 0.3 and _state_t - delta <= 0.3 and near < 1.2:
				Hazards.hurt(self, global_position)
			if _state_t > 0.6:
				stoop = 0.0
				_go(State.CHASE if near < 3.0 else State.BACK)
				if mood == State.BACK:
					_back()
		State.BACK:
			if not is_going():
				_rest = 3.0
				_go(State.STROLL)
	super(delta)


## Back to the nearest point of their walk.
func _back() -> void:
	var best := 0
	for i in route.size():
		if route[i].distance_to(global_position) < route[best].distance_to(global_position):
			best = i
	_leg = best
	go_to(route[best])
	_rest = 3.0
	_go(State.BACK)
