class_name Icon
extends Control
## A small symbol drawn in code (no font has them all, and none on the web): for the HUD's counts and the buttons.
## Each is drawn like a sticker (the user, 2026-11-02: "give the UI a pass, the basic shapes are ugly"): filled shapes
## in a dark bark outline over a soft drop shadow, with a touch of shine (UiStyle's colours).

enum Kind { HEART, HEART_EMPTY, CRUMB, CAP, JUMP, DUCK, SPRINT, TAIL, CLOCK, SCURRY, PAUSE, PLAY, COMB, CHECK, UNDO, LEFT, RIGHT, KIT, CROW, OWL, PERCH, PECK, TOOLS }

const INK := Color(0.1, 0.065, 0.045)

var kind := Kind.HEART
var colour := Color.WHITE
## Drawing the shadow pass: every colour is the shadow's.
var _shade := false
## The outline's half width.
var _o := 2.0


static func make(what: Kind, size: float, tint := Color.WHITE) -> Icon:
	var icon := Icon.new()
	icon.kind = what
	icon.colour = tint
	icon.custom_minimum_size = Vector2(size, size)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon


func _draw() -> void:
	var s := minf(size.x, size.y)
	_o = maxf(1.5, s * 0.045)
	# (the shadow first, a little below, then the sticker)
	_shade = true
	draw_set_transform(Vector2(0.0, s * 0.06))
	_paint(s, size * 0.5)
	_shade = false
	draw_set_transform(Vector2.ZERO)
	_paint(s, size * 0.5)


## A colour, or the shadow's on the shadow pass.
func _c(colour_in: Color) -> Color:
	return Color(0.0, 0.0, 0.0, 0.3 * colour_in.a) if _shade else colour_in


## A filled shape in its outline.
func _blob(points: PackedVector2Array, fill: Color) -> void:
	var ring := points.duplicate()
	ring.append(points[0])
	draw_polyline(ring, _c(INK), _o * 2.0, true)
	draw_colored_polygon(points, _c(fill))


## A filled circle in its outline.
func _dot(at: Vector2, r: float, fill: Color) -> void:
	draw_circle(at, r + _o, _c(INK))
	draw_circle(at, r, _c(fill))


## A thick line in its outline (round ends).
func _stroke(points: PackedVector2Array, ink_colour: Color, width: float) -> void:
	draw_polyline(points, _c(INK), width + _o * 2.0, true)
	for end in [points[0], points[points.size() - 1]]:
		draw_circle(end, width * 0.5 + _o, _c(INK))
	draw_polyline(points, _c(ink_colour), width, true)
	for end in [points[0], points[points.size() - 1]]:
		draw_circle(end, width * 0.5, _c(ink_colour))


## A rounded rectangle's outline points.
func _rounded(rect: Rect2, r: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	var corners := [rect.position + Vector2(rect.size.x - r, r), rect.position + Vector2(r, r),
		rect.position + Vector2(r, rect.size.y - r), rect.end - Vector2(r, r)]
	for k in 4:
		for j in 5:
			var a := -PI * 0.5 * k - PI * 0.5 * j / 4.0
			points.append(corners[k] + Vector2(cos(a), sin(a)) * r)
	return points


## An oval's points.
func _oval(at: Vector2, radii: Vector2, turn := 0.0, count := 20) -> PackedVector2Array:
	var points := PackedVector2Array()
	for k in count:
		var a := TAU * k / count
		points.append(at + Vector2(cos(a) * radii.x, sin(a) * radii.y).rotated(turn))
	return points


func _shine(at: Vector2, r: float) -> void:
	if not _shade:
		draw_circle(at, r, Color(1.0, 1.0, 1.0, 0.55))


func _paint(s: float, c: Vector2) -> void:
	var w := maxf(2.5, s * 0.11)
	match kind:
		Kind.HEART, Kind.HEART_EMPTY:
			var points := PackedVector2Array()
			for k in 40:
				var t := TAU * k / 40.0
				var x := 16.0 * pow(sin(t), 3.0)
				var y := -(13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t))
				points.append(c + Vector2(x, y + 1.5) * s / 37.0)
			if kind == Kind.HEART:
				_blob(points, colour)
				_shine(c + Vector2(-s * 0.18, -s * 0.13), s * 0.07)
			else:
				_blob(points, Color(0.18, 0.1, 0.1, 0.75))
		Kind.CRUMB:
			# An apple (the Crumbs are food: Pickup.FOODS): two round lobes, a stem and a leaf, drawn in its own red
			var red := Color(0.86, 0.2, 0.14)
			var body := c + Vector2(0.0, s * 0.07)
			_stroke(PackedVector2Array([c + Vector2(0.0, -s * 0.14), c + Vector2(s * 0.06, -s * 0.36)]), Color(0.45, 0.28, 0.13), s * 0.06)
			_blob(_oval(c + Vector2(s * 0.17, -s * 0.33), Vector2(s * 0.15, s * 0.07), -0.5, 12), Color(0.44, 0.7, 0.24))
			var apple := PackedVector2Array()
			for k in 32:
				var a := TAU * k / 32.0
				var dent := 1.0 - 0.18 * pow(maxf(-sin(a), 0.0), 8.0)
				apple.append(body + Vector2(cos(a) * s * 0.33, sin(a) * s * 0.3 * dent))
			_blob(apple, red)
			if not _shade:
				draw_colored_polygon(_oval(body + Vector2(s * 0.08, s * 0.08), Vector2(s * 0.2, s * 0.17), 0.0, 16), Color(0.6, 0.08, 0.08, 0.45))
			_shine(body + Vector2(-s * 0.15, -s * 0.1), s * 0.07)
		Kind.CROW:
			# A crow's head side on: black, a heavy beak, a bright eye (playing as one: BirdPlayer)
			_blob(PackedVector2Array([c + Vector2(s * 0.08, -s * 0.16), c + Vector2(s * 0.46, s * 0.02), c + Vector2(s * 0.1, s * 0.12)]), Color(0.3, 0.3, 0.36))
			_dot(c + Vector2(-s * 0.08, 0.0), s * 0.3, Color(0.17, 0.17, 0.23))
			if not _shade:
				draw_arc(c + Vector2(-s * 0.08, 0.0), s * 0.22, -2.6, -1.4, 8, Color(0.45, 0.5, 0.75, 0.6), s * 0.05)
			_dot(c + Vector2(s * 0.03, -s * 0.07), s * 0.065, Color(0.98, 0.95, 0.85))
			if not _shade:
				draw_circle(c + Vector2(s * 0.045, -s * 0.07), s * 0.035, INK)
		Kind.OWL:
			# An owl's face: round, two great eyes, ear tufts, a small hooked beak
			var brown := Color(0.64, 0.46, 0.28)
			for side in [-1.0, 1.0]:
				_blob(PackedVector2Array([c + Vector2(side * s * 0.14, -s * 0.26), c + Vector2(side * s * 0.38, -s * 0.46), c + Vector2(side * s * 0.36, -s * 0.14)]), brown.darkened(0.2))
			_dot(c, s * 0.36, brown)
			if not _shade:
				draw_colored_polygon(_oval(c + Vector2(0.0, s * 0.02), Vector2(s * 0.3, s * 0.24), 0.0, 20), Color(0.86, 0.76, 0.6))
			for side in [-1.0, 1.0]:
				_dot(c + Vector2(side * s * 0.14, -s * 0.03), s * 0.11, Color(0.98, 0.66, 0.12))
				if not _shade:
					draw_circle(c + Vector2(side * s * 0.14, -s * 0.03), s * 0.055, INK)
					draw_circle(c + Vector2(side * s * 0.12, -s * 0.06), s * 0.022, Color.WHITE)
			_blob(PackedVector2Array([c + Vector2(-s * 0.05, s * 0.08), c + Vector2(s * 0.05, s * 0.08), c + Vector2(0.0, s * 0.21)]), Color(0.35, 0.28, 0.2))
		Kind.PERCH:
			# A bird's foot gripping a bar: settle on a wire or a post
			_stroke(PackedVector2Array([c + Vector2(-s * 0.4, s * 0.2), c + Vector2(s * 0.4, s * 0.2)]), Color(0.55, 0.38, 0.22), w)
			_stroke(PackedVector2Array([c + Vector2(0.0, -s * 0.36), c + Vector2(0.0, s * 0.08)]), colour, w * 0.8)
			for dx in [-0.17, 0.0, 0.17]:
				var claw := PackedVector2Array()
				for k in 7:
					claw.append(c + Vector2(dx * s, s * 0.2) + Vector2.from_angle(PI + PI * k / 6.0) * s * 0.09)
				_stroke(claw, colour, w * 0.55)
		Kind.PECK:
			# A beak striking down, and the knock it makes
			_blob(PackedVector2Array([c + Vector2(-s * 0.2, -s * 0.36), c + Vector2(s * 0.1, -s * 0.36), c + Vector2(s * 0.01, s * 0.1)]), Color(0.98, 0.8, 0.3))
			for k in 3:
				var a := lerpf(-0.7, 0.7, k / 2.0) + PI * 0.5
				var at := c + Vector2(0.0, s * 0.22)
				_stroke(PackedVector2Array([at + Vector2.from_angle(a) * s * 0.1, at + Vector2.from_angle(a) * s * 0.24]), colour, w * 0.55)
		Kind.KIT:
			# A kit's face (the lost kits: LostKits): round grey head, ears, the black mask, a pale muzzle and nose
			var grey := Color(0.66, 0.62, 0.6)
			for side in [-1.0, 1.0]:
				_dot(c + Vector2(side * s * 0.26, -s * 0.27), s * 0.11, grey)
				if not _shade:
					draw_circle(c + Vector2(side * s * 0.26, -s * 0.26), s * 0.055, Color(0.25, 0.2, 0.2))
			_dot(c + Vector2(0.0, s * 0.04), s * 0.34, grey)
			if not _shade:
				var brow := PackedVector2Array([c + Vector2(-s * 0.06, -s * 0.24), c + Vector2(s * 0.06, -s * 0.24), c + Vector2(0.0, -s * 0.06)])
				draw_colored_polygon(brow, Color(0.3, 0.27, 0.27))
				for side in [-1.0, 1.0]:
					draw_colored_polygon(_oval(c + Vector2(side * s * 0.15, s * 0.0), Vector2(s * 0.15, s * 0.09), side * 0.25, 14), Color(0.09, 0.08, 0.09))
					draw_circle(c + Vector2(side * s * 0.13, -s * 0.01), s * 0.045, Color.WHITE)
					draw_circle(c + Vector2(side * s * 0.13, -s * 0.01), s * 0.02, INK)
				draw_colored_polygon(_oval(c + Vector2(0.0, s * 0.2), Vector2(s * 0.14, s * 0.1), 0.0, 14), Color(0.95, 0.93, 0.88))
				draw_colored_polygon(_oval(c + Vector2(0.0, s * 0.15), Vector2(s * 0.06, s * 0.04), 0.0, 10), INK)
		Kind.CAP:
			# A bottlecap: a crimped gold rim, the red top, a shine
			var rim := PackedVector2Array()
			for k in 36:
				rim.append(c + Vector2.from_angle(TAU * k / 36.0) * s * (0.44 if k % 2 else 0.39))
			_blob(rim, colour)
			_dot(c, s * 0.27, Color(0.82, 0.16, 0.14))
			if not _shade:
				draw_arc(c, s * 0.19, -2.5, -1.2, 10, Color(1.0, 1.0, 1.0, 0.55), s * 0.05)
				draw_circle(c, s * 0.08, colour)
		Kind.JUMP:
			# A chunky arrow up off a puff of dust
			_blob(PackedVector2Array([c + Vector2(0.0, -s * 0.42), c + Vector2(s * 0.3, -s * 0.08), c + Vector2(s * 0.11, -s * 0.08),
				c + Vector2(s * 0.11, s * 0.2), c + Vector2(-s * 0.11, s * 0.2), c + Vector2(-s * 0.11, -s * 0.08), c + Vector2(-s * 0.3, -s * 0.08)]), colour)
			for dx in [-0.22, 0.0, 0.22]:
				_dot(c + Vector2(dx * s, s * 0.36), s * (0.06 if dx != 0.0 else 0.08), Color(0.85, 0.78, 0.65))
		Kind.DUCK:
			# A chunky arrow down onto the ground
			_blob(PackedVector2Array([c + Vector2(0.0, s * 0.22), c + Vector2(s * 0.3, -s * 0.1), c + Vector2(s * 0.11, -s * 0.1),
				c + Vector2(s * 0.11, -s * 0.4), c + Vector2(-s * 0.11, -s * 0.4), c + Vector2(-s * 0.11, -s * 0.1), c + Vector2(-s * 0.3, -s * 0.1)]), colour)
			_stroke(PackedVector2Array([c + Vector2(-s * 0.34, s * 0.37), c + Vector2(s * 0.34, s * 0.37)]), Color(0.55, 0.72, 0.32), w * 0.8)
		Kind.SPRINT:
			for dx in [-0.18, 0.12]:
				_stroke(PackedVector2Array([c + Vector2((dx - 0.12) * s, -0.3 * s), c + Vector2((dx + 0.14) * s, 0.0), c + Vector2((dx - 0.12) * s, 0.3 * s)]), colour, w)
		Kind.TAIL:
			# His ringed tail curled round in a whirl: grey and black bands, the tip black
			var curl := PackedVector2Array()
			var widths: Array[float] = []
			for k in 30:
				var t := k / 29.0
				curl.append(c + Vector2.from_angle(PI * 0.75 + t * TAU * 1.15) * s * (0.4 - 0.27 * t))
				widths.append(s * lerpf(0.2, 0.09, t))
			for k in curl.size():
				draw_circle(curl[k], widths[k] * 0.5 + _o, _c(INK))
			for k in curl.size():
				var band := (k / 4) % 2 == 0 and k < curl.size() - 3
				draw_circle(curl[k], widths[k] * 0.5, _c(Color(0.72, 0.68, 0.64) if band else Color(0.17, 0.15, 0.16)))
			if not _shade:
				for k in range(2, curl.size(), 8):
					draw_circle(curl[k] + Vector2(-widths[k] * 0.15, -widths[k] * 0.15), widths[k] * 0.14, Color(1.0, 1.0, 1.0, 0.35))
		Kind.SCURRY:
			# A raccoon's fore paw print: a wide palm pad and five long fingers
			var palm := c + Vector2(0.0, s * 0.17)
			for k in 5:
				var a := lerpf(-2.6, -0.54, k / 4.0)
				var reach := 0.36 if k in [1, 2, 3] else 0.3
				_blob(_oval(palm + Vector2.from_angle(a) * s * reach, Vector2(s * 0.075, s * 0.13), a + PI * 0.5, 14), colour)
			_blob(_oval(palm, Vector2(s * 0.29, s * 0.2), 0.0, 22), colour)
		Kind.CLOCK:
			_blob(_rounded(Rect2(c + Vector2(-s * 0.08, -s * 0.5), Vector2(s * 0.16, s * 0.12)), s * 0.03), colour)
			_dot(c + Vector2(0.0, s * 0.04), s * 0.36, colour)
			if not _shade:
				draw_circle(c + Vector2(0.0, s * 0.04), s * 0.27, Color(0.98, 0.95, 0.88))
			_stroke(PackedVector2Array([c + Vector2(0.0, s * 0.04), c + Vector2(s * 0.12, -s * 0.12)]), INK, w * 0.5)
		Kind.PAUSE:
			for dx in [-0.15, 0.15]:
				_blob(_rounded(Rect2(c + Vector2(dx * s - s * 0.09, -s * 0.3), Vector2(s * 0.18, s * 0.6)), s * 0.05), colour)
		Kind.PLAY:
			var tri := PackedVector2Array()
			var corners := [c + Vector2(-s * 0.2, -s * 0.32), c + Vector2(s * 0.32, 0.0), c + Vector2(-s * 0.2, s * 0.32)]
			for k in 3:
				var at: Vector2 = corners[k]
				var before: Vector2 = corners[(k + 2) % 3]
				var after: Vector2 = corners[(k + 1) % 3]
				tri.append(at.lerp(before, 0.12))
				tri.append(at.lerp(before, 0.04).lerp(at.lerp(after, 0.04), 0.5))
				tri.append(at.lerp(after, 0.12))
			_blob(tri, colour)
		Kind.COMB:
			# A comb: a back and its teeth (the fur editor)
			for k in 7:
				var x := lerpf(-0.31, 0.31, k / 6.0) * s
				_stroke(PackedVector2Array([c + Vector2(x, -s * 0.12), c + Vector2(x, s * 0.32)]), colour, w * 0.45)
			_blob(_rounded(Rect2(c + Vector2(-s * 0.4, -s * 0.32), Vector2(s * 0.8, s * 0.2)), s * 0.06), Color(0.9, 0.62, 0.3))
		Kind.CHECK:
			_stroke(PackedVector2Array([c + Vector2(-s * 0.3, 0.0), c + Vector2(-s * 0.08, s * 0.24), c + Vector2(s * 0.32, -s * 0.26)]), Color(0.62, 0.86, 0.36), w)
		Kind.UNDO:
			var arc := PackedVector2Array()
			for k in 24:
				arc.append(c + Vector2.from_angle(lerpf(-2.4, 2.0, k / 23.0)) * s * 0.27)
			_stroke(arc, colour, w * 0.85)
			var tip := arc[0]
			_blob(PackedVector2Array([tip + Vector2(-s * 0.17, -s * 0.03), tip + Vector2(s * 0.11, -s * 0.14), tip + Vector2(s * 0.05, s * 0.15)]), colour)
		Kind.LEFT, Kind.RIGHT:
			var way := -1.0 if kind == Kind.LEFT else 1.0
			_stroke(PackedVector2Array([c + Vector2(-way * s * 0.12, -s * 0.28), c + Vector2(way * s * 0.16, 0.0), c + Vector2(-way * s * 0.12, s * 0.28)]), colour, w)
		Kind.TOOLS:
			# A spanner: the testing panel
			_stroke(PackedVector2Array([c + Vector2(-s * 0.26, s * 0.26), c + Vector2(s * 0.1, -s * 0.1)]), colour, w)
			_dot(c + Vector2(s * 0.17, -s * 0.17), s * 0.16, colour)
			if not _shade:
				draw_colored_polygon(_oval(c + Vector2(s * 0.24, -s * 0.24), Vector2(s * 0.09, s * 0.06), -PI * 0.25, 10), Color(0.13, 0.23, 0.17))
