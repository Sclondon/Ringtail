class_name HazardCrows
extends Node3D
## A little band of crows hanging about one spot (a `crows_<n>` marker): HazardBirds hopping on the ground. While the
## raccoon is near, the band sends one of them at a time to dive-bomb him (Claude's picks: how near, how often).

var home := Vector3.ZERO
var count := 4
var player: Player
## How near he must be for them to go for him, and the wait between dives.
var notice := 7.0
var every := Vector2(1.8, 3.2)

var crows: Array[HazardBird] = []
var _wait := 2.0


func _ready() -> void:
	for k in count:
		var crow := HazardBird.new()
		crow.kind = HazardBird.Kind.CROW
		var a := TAU * k / count
		crow.home = home + Vector3(cos(a), 0.0, sin(a)) * 1.2
		crow.player = player
		add_child(crow)
		crows.append(crow)


func _physics_process(delta: float) -> void:
	if player == null:
		return
	_wait -= delta
	if _wait > 0.0 or player.global_position.distance_to(home) > notice or Hazards.unseen(player):
		return
	_wait = randf_range(every.x, every.y)
	crows.shuffle()
	for crow in crows:
		if crow.dive():
			return
