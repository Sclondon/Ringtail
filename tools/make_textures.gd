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
	_save("asphalt", _asphalt())
	_save("metal", _metal())
	_save("stone", _stone())
	_save("blockwall", _blockwall())
	_save("tiles", _tiles())
	_save("plaster", _concrete(Color(0.93, 0.9, 0.82), 0.03))
	_save("thatch", _thatch())
	_save("anime_tree", _anime_tree())
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


## The concrete-block retaining walls of the hillside streets (Whisper of the Heart): pale blocks in staggered
## courses with slanted joints, each with a dark slot pressed in its face.
func _blockwall() -> Image:
	var base := Color(0.84, 0.84, 0.8)
	var image := _blank(base)
	var course := 16
	for y in SIZE:
		var row := y / course
		var within := y % course
		for x in SIZE:
			# (the joints between blocks lean one way on one course, the other way on the next)
			var lean := (within - course / 2) * (1 if row % 2 == 0 else -1) / 2
			var u := (x + lean + (16 if row % 2 == 1 else 0) + SIZE) % 32
			var shade := 1.0 + _n(x * 2.0, y * 2.0) * 0.08
			if within == 0:
				shade = 1.12
			elif within >= course - 1 or u == 0:
				shade = 0.62
			elif u == 1:
				shade = 1.1
			# the slot in the block's face
			var slot_y := within - course / 2
			if absi(slot_y) <= 1 and u >= 10 and u <= 22 and absi(u - 16) <= 6 - absi(slot_y):
				shade = 0.55 if slot_y <= 0 else 0.75
			image.set_pixel(x, y, _shade(base, shade))
	return image


## Japanese roof tiles: rounded rows running down the roof, the courses overlapping across it.
func _tiles() -> Image:
	var base := Color(0.62, 0.66, 0.72)
	var image := _blank(base)
	var course := 16
	for y in SIZE:
		var within := y % course
		for x in SIZE:
			var round_x := sin(x * TAU / 16.0)
			var shade := 1.0 + round_x * 0.16 - 0.18 * float(within) / course + _n(x * 2.0, y * 2.0) * 0.05
			if within >= course - 2:
				shade = 0.55 + 0.1 * round_x
			image.set_pixel(x, y, _shade(base, shade))
	return image


## Thatch: straw laid down the roof in thick rows, lighter at the cut ends.
func _thatch() -> Image:
	var base := Color(0.7, 0.58, 0.36)
	var image := _blank(base)
	var rng := RandomNumberGenerator.new()
	rng.seed = 31
	var streak := []
	for x in SIZE:
		streak.append(rng.randf_range(0.8, 1.15))
	for y in SIZE:
		var within := y % 21
		for x in SIZE:
			var shade: float = streak[x] * (1.08 - 0.4 * float(within) / 21.0) + _n(x * 3.0, y) * 0.06
			image.set_pixel(x, y, _shade(base, shade))
	return image


## Tarmac (the user, 2026-11-02: "less repetitive texture"): fine grit, a patch of newer and one of older surface
## with their seams, a few branching cracks, an oil stain, two worn tyre tracks. The world shader breaks up its repeat
## further with a slow variation in world space (World sets `variation` on the roads).
func _asphalt() -> Image:
	var base := Color(0.33, 0.33, 0.36)
	var image := _blank(base)
	var rng := RandomNumberGenerator.new()
	rng.seed = 41
	for y in SIZE:
		for x in SIZE:
			var tone := 1.0 + _n(x * 2.0, y * 2.0) * 0.07 + rng.randf_range(-0.06, 0.06)
			# (two worn tracks along it, a little lighter and smoother)
			var track := absf(fmod(float(x) + 64.0, 32.0) - 16.0)
			if track < 3.0:
				tone += 0.05
			image.set_pixel(x, y, _shade(base, tone))
	# a newer patch (darker, a seam round it) and an older one (paler)
	for patch: Array in [[Vector2i(6, 10), Vector2i(22, 16), 0.9], [Vector2i(38, 40), Vector2i(20, 14), 1.07]]:
		var at: Vector2i = patch[0]
		var size: Vector2i = patch[1]
		for y in size.y:
			for x in size.x:
				var p := Vector2i((at.x + x) % SIZE, (at.y + y) % SIZE)
				var seam := x == 0 or y == 0 or x == size.x - 1 or y == size.y - 1
				image.set_pixel(p.x, p.y, _shade(image.get_pixel(p.x, p.y), 0.82 if seam else float(patch[2])))
	# cracks, branching
	for k in 3:
		var p := Vector2(rng.randi_range(0, SIZE - 1), rng.randi_range(0, SIZE - 1))
		var way := Vector2.from_angle(rng.randf_range(0.0, TAU))
		for step in 26:
			way = way.rotated(rng.randf_range(-0.6, 0.6))
			p += way
			image.set_pixel(posmod(int(p.x), SIZE), posmod(int(p.y), SIZE), _shade(base, 0.45))
	# an oil stain
	var stain := Vector2(rng.randi_range(0, SIZE - 1), rng.randi_range(0, SIZE - 1))
	for dy in range(-5, 6):
		for dx in range(-7, 8):
			var d := Vector2(dx / 7.0, dy / 5.0).length()
			if d < 1.0:
				var p := Vector2i(posmod(int(stain.x) + dx, SIZE), posmod(int(stain.y) + dy, SIZE))
				image.set_pixel(p.x, p.y, _shade(image.get_pixel(p.x, p.y), 0.7 + 0.3 * d))
	return image


## A tree painted flat, as in a Ghibli background (the user, 2026-11-02: "some 2D anime style trees"): a clumpy
## rounded crown of overlapping billows, lit along its top edge, shadowed on its lower right, a thin dark trunk, in
## greys (the far hills' vertex colours give each its hazy green). Transparent round it.
func _anime_tree() -> Image:
	var image := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var rng := RandomNumberGenerator.new()
	rng.seed = 23
	var billows: Array[Vector3] = []
	for k in 9:
		var a := TAU * k / 9.0
		billows.append(Vector3(32.0 + cos(a) * rng.randf_range(12.0, 17.0), 30.0 + sin(a) * rng.randf_range(9.0, 14.0), rng.randf_range(9.0, 12.0)))
	billows.append(Vector3(32.0, 28.0, 15.0))
	billows.append(Vector3(29.0, 14.0, 10.0))
	# the trunk
	for y in range(44, SIZE):
		for x in range(30, 34):
			image.set_pixel(x, y, Color(0.32, 0.3, 0.28, 1.0))
	for y in SIZE:
		for x in SIZE:
			var inside := false
			var lit := 0.0
			for b in billows:
				var d := Vector2(x - b.x, y - b.y)
				if d.length() < b.z:
					inside = true
					# (lit from the upper left: the near edge of each billow towards the light paler)
					lit = maxf(lit, clampf((-d.x * 0.5 - d.y) / b.z, 0.0, 1.0))
			if not inside:
				continue
			# (the lower right of the crown in shadow)
			var shadow := clampf(((x - 32.0) * 0.6 + (y - 22.0)) / 18.0, 0.0, 1.0)
			var tone := 0.78 + 0.22 * smoothstep(0.55, 0.95, lit) - 0.28 * shadow
			image.set_pixel(x, y, Color(tone, tone, tone, 1.0))
	return image
