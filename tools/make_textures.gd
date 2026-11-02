extends SceneTree
## Paints the world's textures in the Banjo-Kazooie way (the user, 2026-11-01: "we'll need banjo kazooie style
## textures too"): small (64 px) and bright, painted rather than photographed, soft-edged shapes with a light top
## edge and a dark bottom one, filtered smooth in the game. One PNG each in textures/:
##   godot --headless --path . -s res://tools/make_textures.gd
## The world shader tiles them by metres (World.TEXTURES says how many to a tile) and shades them with the
## model's vertex colours.

const SIZE := 64
var noise := FastNoiseLite.new()


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute("res://textures")
	noise.seed = 4
	noise.frequency = 0.08
	_save("grass", _grass())
	_save("dirt", _dirt())
	_save("brick", _brick())
	_save("siding", _siding())
	_save("shingles", _shingles())
	_save("planks", _planks(false))
	_save("fence", _planks(true))
	_save("concrete", _concrete(Color(0.62, 0.61, 0.58), 0.07))
	_save("asphalt", _concrete(Color(0.32, 0.32, 0.35), 0.06))
	_save("metal", _metal())
	_save("stone", _stone())
	print("TEXTURES DONE")
	quit()


func _save(name: String, image: Image) -> void:
	image.save_png("res://textures/%s.png" % name)
	print("painted ", name)


func _blank(colour: Color) -> Image:
	var image := Image.create(SIZE, SIZE, false, Image.FORMAT_RGB8)
	image.fill(colour)
	return image


## Tileable noise in -1..1 (sampled on a torus so it wraps).
func _n(x: float, y: float, scale := 1.0) -> float:
	var a := TAU * x / SIZE
	var b := TAU * y / SIZE
	var r := SIZE / TAU * scale
	return noise.get_noise_3d(cos(a) * r, sin(a) * r + cos(b) * r, sin(b) * r)


func _shade(c: Color, by: float) -> Color:
	return Color(clampf(c.r * by, 0.0, 1.0), clampf(c.g * by, 0.0, 1.0), clampf(c.b * by, 0.0, 1.0))


func _grass() -> Image:
	var image := _blank(Color.BLACK)
	for y in SIZE:
		for x in SIZE:
			var n := _n(x, y) * 0.5 + _n(x * 3.0, y * 3.0, 0.5) * 0.25
			image.set_pixel(x, y, _shade(Color(0.38, 0.7, 0.22), 0.92 + n * 0.35))
	# Blades: little dark-and-light strokes
	var rng := RandomNumberGenerator.new()
	rng.seed = 2
	for k in 70:
		var x := rng.randi_range(0, SIZE - 1)
		var y := rng.randi_range(0, SIZE - 1)
		for j in 3:
			image.set_pixel((x + j / 2) % SIZE, (y - j + SIZE) % SIZE, Color(0.26, 0.5, 0.16) if j < 2 else Color(0.62, 0.9, 0.4))
	return image


func _dirt() -> Image:
	var image := _blank(Color.BLACK)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for y in SIZE:
		for x in SIZE:
			image.set_pixel(x, y, _shade(Color(0.6, 0.43, 0.27), 0.9 + _n(x * 2.0, y * 2.0) * 0.3))
	for k in 30:
		var c := Vector2i(rng.randi_range(0, SIZE - 1), rng.randi_range(0, SIZE - 1))
		_blob(image, c, rng.randf_range(1.0, 2.2), Color(0.72, 0.6, 0.45), Color(0.42, 0.3, 0.2))
	return image


## A soft pebble: lit on top, a shadow under it.
func _blob(image: Image, c: Vector2i, r: float, light: Color, dark: Color) -> void:
	for dy in range(-3, 4):
		for dx in range(-3, 4):
			var d := Vector2(dx, dy).length()
			if d <= r:
				var p := Vector2i((c.x + dx + SIZE) % SIZE, (c.y + dy + SIZE) % SIZE)
				image.set_pixel(p.x, p.y, light.lerp(dark, clampf((dy / r) * 0.5 + 0.5, 0.0, 1.0)))


func _brick() -> Image:
	var mortar := Color(0.82, 0.78, 0.68)
	var image := _blank(mortar)
	var rows := 8
	var h := SIZE / rows
	var w := SIZE / 4
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	for row in rows:
		var offset := (w / 2) * (row % 2)
		for col in 5:
			var tint := rng.randf_range(0.85, 1.1)
			var base := Color(0.74, 0.32, 0.22) * tint
			for y in range(1, h - 1):
				for x in range(1, w - 1):
					var px := (col * w + x + offset) % SIZE
					var py := row * h + y
					var edge := 1.0
					if y == 1:
						edge = 1.18
					elif y == h - 2:
						edge = 0.72
					image.set_pixel(px, py, _shade(base, edge * (0.95 + _n(px * 2.0, py * 2.0) * 0.12)))
	return image


func _siding() -> Image:
	var image := _blank(Color.BLACK)
	var boards := 6
	var h := SIZE / boards
	for y in SIZE:
		var within := y % h
		# (each board lit along its top, shadowed under the lap of the one above)
		var light := 1.12 if within == 0 else (0.7 if within == h - 1 else 1.0 - 0.1 * float(within) / h)
		for x in SIZE:
			image.set_pixel(x, y, _shade(Color(0.6, 0.72, 0.82), light * (0.97 + _n(x * 4.0, y) * 0.05)))
	return image


func _shingles() -> Image:
	var image := _blank(Color(0.25, 0.12, 0.1))
	var rows := 4
	var h := SIZE / rows
	var w := SIZE / 4
	for row in rows:
		var offset := (w / 2) * (row % 2)
		for col in 5:
			for y in h:
				for x in w - 1:
					# A tab with a rounded bottom edge
					var u := (x - w * 0.5 + 0.5) / (w * 0.5)
					if float(y) > h - 1 - 3.0 * (u * u):
						continue
					var px := (col * w + x + offset) % SIZE
					var py := row * h + y
					var light := 1.15 - 0.45 * float(y) / h
					image.set_pixel(px, py, _shade(Color(0.66, 0.3, 0.22), light * (0.95 + _n(px * 3.0, py * 3.0) * 0.1)))
	return image


func _planks(fence: bool) -> Image:
	var image := _blank(Color.BLACK)
	var boards := 4
	var w := SIZE / boards
	var rng := RandomNumberGenerator.new()
	rng.seed = 11 if fence else 13
	var base := Color(0.78, 0.6, 0.38) if fence else Color(0.66, 0.46, 0.28)
	for b in boards:
		var tint := rng.randf_range(0.88, 1.08)
		for x in w:
			var edge := 1.15 if x == 0 else (0.62 if x == w - 1 else 1.0)
			for y in SIZE:
				var grain := sin(y * 0.55 + b * 2.0 + _n(b * w + x, y) * 3.0) * 0.05
				image.set_pixel(b * w + x, y, _shade(base, tint * edge * (1.0 + grain)))
		# Two nails
		for ny in [6, SIZE - 8]:
			image.set_pixel(b * w + w / 2, ny, Color(0.25, 0.2, 0.18))
	return image


func _concrete(base: Color, speckle: float) -> Image:
	var image := _blank(Color.BLACK)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(base.r * 100.0)
	for y in SIZE:
		for x in SIZE:
			image.set_pixel(x, y, _shade(base, 1.0 + _n(x, y) * 0.12 + rng.randf_range(-speckle, speckle)))
	# A crack
	var at := Vector2(10, 40)
	for k in 30:
		at += Vector2(1.0, rng.randf_range(-1.2, 0.8))
		image.set_pixel(int(at.x) % SIZE, (int(at.y) + SIZE) % SIZE, _shade(base, 0.55))
	return image


func _metal() -> Image:
	var image := _blank(Color.BLACK)
	for y in SIZE:
		for x in SIZE:
			# Corrugated ribs across it
			var rib := sin(x * TAU / 8.0)
			image.set_pixel(x, y, _shade(Color(0.66, 0.7, 0.72), 1.0 + rib * 0.16 + _n(x, y * 2.0) * 0.05))
	return image


func _stone() -> Image:
	var image := _blank(Color(0.4, 0.38, 0.36))
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	for k in 22:
		var c := Vector2i(rng.randi_range(0, SIZE - 1), rng.randi_range(0, SIZE - 1))
		var r := rng.randf_range(5.0, 9.0)
		var base := Color(0.64, 0.62, 0.58) * rng.randf_range(0.85, 1.08)
		for dy in range(-10, 11):
			for dx in range(-10, 11):
				var d := Vector2(dx, dy * 1.2).length()
				if d < r:
					var p := Vector2i((c.x + dx + SIZE) % SIZE, (c.y + dy + SIZE) % SIZE)
					image.set_pixel(p.x, p.y, _shade(base, 1.15 - 0.35 * (float(dy) / r * 0.5 + 0.5)))
	return image
