class_name WaterSpring
extends Node3D
## A spring welling up through a pool of `Water`: a gentle boil where it comes up (the surface churning white and a
## ring opening on it every moment), strings of bubbles rising from the bottom and popping at the top in little
## rings, and froth drifting out over the surface from the boil. Two particle draws and a FoamPatch; the rings are
## the Water's own. Made for Ringtail's grove spring (2026-11-02).
##
##   var spring := WaterSpring.new()
##   spring.water = pool_water      # the Water it wells up in (this node goes where it comes up, on the bottom)
##   spring.position = Vector3(0.0, -0.6, 0.0)
##   pool_water.add_child(spring)

## The pool it comes up in.
@export var water: Water
## How hard it wells up (0.5 a trickle, 1 a lively spring, 2 a boil), and how wide the bubbles come up round it.
@export_range(0.0, 3.0) var strength := 1.0
@export var reach := 0.55

var _bubbles: CPUParticles3D
var _froth: CPUParticles3D
var _boil: FoamPatch
var _ring_in := 0.0
var _pop_in := 0.0


func _ready() -> void:
	var depth := _depth()
	_boil = FoamPatch.new()
	_boil.radius = reach * 0.9
	_boil.strength = clampf(0.45 * strength, 0.0, 1.0)
	_boil.speed = 0.35
	_boil.position = Vector3.UP * (depth + 0.008)
	add_child(_boil)
	# (bubbles: little bright beads wobbling up from the bottom, just reaching the top as they die)
	_bubbles = CPUParticles3D.new()
	_bubbles.amount = maxi(4, roundi(28.0 * strength))
	var rise := 0.55
	_bubbles.lifetime = maxf(depth / rise, 0.2)
	_bubbles.direction = Vector3.UP
	_bubbles.spread = 6.0
	_bubbles.initial_velocity_min = rise * 0.85
	_bubbles.initial_velocity_max = rise * 1.15
	_bubbles.gravity = Vector3.ZERO
	_bubbles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_bubbles.emission_sphere_radius = reach * 0.6
	_bubbles.scale_amount_min = 0.5
	_bubbles.scale_amount_max = 1.3
	var bead := SphereMesh.new()
	bead.radius = 0.018
	bead.height = 0.036
	bead.radial_segments = 6
	bead.rings = 3
	var shine := StandardMaterial3D.new()
	shine.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shine.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shine.albedo_color = Color(0.9, 0.98, 1.0, 0.75)
	bead.material = shine
	_bubbles.mesh = bead
	add_child(_bubbles)
	# (froth: flecks of white drifting out over the surface from the boil, fading)
	_froth = CPUParticles3D.new()
	_froth.position = Vector3.UP * (depth + 0.01)
	_froth.amount = maxi(4, roundi(18.0 * strength))
	_froth.lifetime = 2.4
	_froth.direction = Vector3.RIGHT
	_froth.spread = 180.0
	_froth.flatness = 1.0
	_froth.initial_velocity_min = 0.08
	_froth.initial_velocity_max = 0.25
	_froth.damping_min = 0.02
	_froth.damping_max = 0.05
	_froth.gravity = Vector3.ZERO
	_froth.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_froth.emission_sphere_radius = reach * 0.3
	var fade := Curve.new()
	fade.add_point(Vector2(0.0, 0.4))
	fade.add_point(Vector2(0.2, 1.0))
	fade.add_point(Vector2(1.0, 0.0))
	_froth.scale_amount_curve = fade
	var fleck := SphereMesh.new()
	fleck.radius = 0.035
	fleck.height = 0.012
	fleck.radial_segments = 6
	fleck.rings = 2
	var white := StandardMaterial3D.new()
	white.albedo_color = Color(0.95, 0.99, 1.0)
	white.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fleck.material = white
	_froth.mesh = fleck
	add_child(_froth)


## How far it is from here up to the surface.
func _depth() -> float:
	if water and water.is_inside_tree() and is_inside_tree():
		return maxf(water.surface_y() - global_position.y, 0.05)
	return maxf(-position.y, 0.05)


func _process(delta: float) -> void:
	if water == null or not is_instance_valid(water):
		return
	var top := Vector3(global_position.x, water.surface_y(), global_position.z)
	# (the boil: a ring opening from it every moment)
	_ring_in -= delta
	if _ring_in <= 0.0:
		_ring_in = randf_range(0.35, 0.6) / maxf(strength, 0.2)
		water.ripple(top + Vector3(randf_range(-0.1, 0.1), 0.0, randf_range(-0.1, 0.1)), 0.35 + 0.15 * strength)
	# (bubbles popping out round it in small rings)
	_pop_in -= delta
	if _pop_in <= 0.0:
		_pop_in = randf_range(0.12, 0.35) / maxf(strength, 0.2)
		var a := randf() * TAU
		water.ripple(top + Vector3(cos(a), 0.0, sin(a)) * randf_range(0.1, reach), randf_range(0.12, 0.22))
