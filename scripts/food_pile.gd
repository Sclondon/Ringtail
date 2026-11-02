class_name FoodPile
extends Node3D
## The band's hoard in the grove: a heap of food that grows with every bit he finds (the user, 2026-11-02: "there
## should be a big pile of food in the grove as well that grows as you collect the food"). Each Crumb taken adds one
## of the foods (Pickup.FOODS) to the heap, which spreads and rises as it grows. It starts with a few.
##
##   FoodPile.place(world, at)

## How many it starts with, and how the heap grows: its spread and its height for so many.
const START := 6
const MOST := 400

var _count := 0
var _rng := RandomNumberGenerator.new()


static func place(world: World, at: Vector3) -> FoodPile:
	var pile := FoodPile.new()
	pile.name = "FoodPile"
	pile.position = at
	pile._rng.seed = 23
	world.add_child(pile)
	for k in START:
		pile.add_one()
	world.crumbs_changed.connect(func(count: int, _total: int) -> void:
		while pile._count < START + count and pile._count < MOST:
			pile.add_one())
	return pile


## One more on the heap: somewhere on its slope, lying as it falls.
func add_one() -> void:
	var weights := 0
	for food: Array in Pickup.FOODS:
		weights += int(food[1])
	var pick := _rng.randi() % weights
	var chosen: Array = Pickup.FOODS[0]
	for food: Array in Pickup.FOODS:
		pick -= int(food[1])
		if pick < 0:
			chosen = food
			break
	var model: Node3D = (chosen[0] as PackedScene).instantiate()
	Toon.apply(model)
	# (the heap: a mound as wide as it is so many, highest in the middle)
	var n := float(_count)
	var spread := 0.22 + 0.07 * sqrt(n)
	var height := 0.12 + 0.045 * sqrt(n)
	var a := _rng.randf() * TAU
	var d := sqrt(_rng.randf()) * spread
	var y := height * (1.0 - d / spread) + _rng.randf_range(-0.03, 0.03)
	model.position = Vector3(cos(a) * d, maxf(y, 0.0), sin(a) * d)
	model.rotation = Vector3(float(chosen[2]) + _rng.randf_range(-0.6, 0.6), _rng.randf() * TAU, _rng.randf_range(-0.5, 0.5))
	model.scale = Vector3.ONE * float(chosen[3]) * _rng.randf_range(0.85, 1.1)
	add_child(model)
	_count += 1
