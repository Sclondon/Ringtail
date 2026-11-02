class_name Icon
extends Control
## A small symbol drawn in code (no font has them all, and none on the web):
## for the HUD's counts and the buttons.

enum Kind { HEART, HEART_EMPTY, CRUMB, CAP, JUMP, DUCK, SPRINT, TAIL, CLOCK }

var kind := Kind.HEART
var colour := Color.WHITE


static func make(what: Kind, size: float, tint := Color.WHITE) -> Icon:
	var icon := Icon.new()
	icon.kind = what
	icon.colour = tint
	icon.custom_minimum_size = Vector2(size, size)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon


func _draw() -> void:
	var s := minf(size.x, size.y)
	var c := size * 0.5
	var ink := Color(0.08, 0.05, 0.1)
	var w := maxf(2.0, s * 0.09)
	match kind:
		Kind.HEART, Kind.HEART_EMPTY:
			var points := PackedVector2Array()
			for k in 40:
				var t := TAU * k / 40.0
				var x := 16.0 * pow(sin(t), 3.0)
				var y := -(13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t))
				points.append(c + Vector2(x, y) * s / 36.0)
			if kind == Kind.HEART:
				draw_colored_polygon(points, colour)
			points.append(points[0])
			draw_polyline(points, ink if kind == Kind.HEART else colour, w * 0.8, true)
		Kind.CRUMB:
			# An apple (the Crumbs are food: Pickup.FOODS): two round lobes, a stem and a leaf, drawn in its own red
			var red := Color(0.88, 0.16, 0.12)
			var body := c + Vector2(0.0, s * 0.06)
			for dx in [-0.11, 0.11]:
				draw_circle(body + Vector2(dx * s, 0.0), s * 0.31, ink)
			for dx in [-0.11, 0.11]:
				draw_circle(body + Vector2(dx * s, 0.0), s * 0.25, red)
			draw_circle(body + Vector2(-0.14 * s, -0.1 * s), s * 0.07, Color(1.0, 0.6, 0.55))
			draw_line(c + Vector2(0.0, -s * 0.18), c + Vector2(s * 0.05, -s * 0.38), Color(0.4, 0.25, 0.12), maxf(2.0, s * 0.07))
			var leaf := PackedVector2Array([c + Vector2(s * 0.04, -s * 0.3), c + Vector2(s * 0.2, -s * 0.42),
				c + Vector2(s * 0.3, -s * 0.34), c + Vector2(s * 0.16, -s * 0.26)])
			draw_colored_polygon(leaf, Color(0.36, 0.72, 0.2))
		Kind.CAP:
			var rim := PackedVector2Array()
			for k in 28:
				rim.append(c + Vector2.from_angle(TAU * k / 28.0) * s * (0.46 if k % 2 else 0.4))
			draw_colored_polygon(rim, colour)
			draw_circle(c, s * 0.3, Color(0.85, 0.16, 0.14))
			draw_circle(c, s * 0.1, colour)
		Kind.JUMP, Kind.DUCK:
			var up := -1.0 if kind == Kind.JUMP else 1.0
			draw_line(c + Vector2(0, -up * s * 0.32), c + Vector2(0, up * s * 0.3), colour, w)
			draw_polyline(PackedVector2Array([c + Vector2(-s * 0.26, up * s * 0.06), c + Vector2(0, up * s * 0.34), c + Vector2(s * 0.26, up * s * 0.06)]), colour, w)
			draw_line(c + Vector2(-s * 0.34, -up * s * 0.4), c + Vector2(s * 0.34, -up * s * 0.4), colour, w)
		Kind.SPRINT:
			for dx in [-0.18, 0.12]:
				draw_polyline(PackedVector2Array([c + Vector2((dx - 0.12) * s, -0.3 * s), c + Vector2((dx + 0.14) * s, 0.0), c + Vector2((dx - 0.12) * s, 0.3 * s)]), colour, w)
		Kind.TAIL:
			# A spiral: the tail whirled
			var spiral := PackedVector2Array()
			for k in 40:
				var t := k / 39.0
				spiral.append(c + Vector2.from_angle(t * TAU * 1.6) * s * (0.08 + 0.34 * t))
			draw_polyline(spiral, colour, w, true)
		Kind.CLOCK:
			draw_circle(c, s * 0.42, colour)
			draw_circle(c, s * 0.34, ink)
			draw_line(c, c + Vector2(0, -s * 0.26), colour, w)
			draw_rect(Rect2(c + Vector2(-s * 0.08, -s * 0.56), Vector2(s * 0.16, s * 0.12)), colour)
