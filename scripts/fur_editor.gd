class_name FurEditor
extends Node3D
## The model editor, after Gloaming's character editor (the user, 2026-11-02: "a pause screen and model editor where I
## can switch out the fur with different texture types like the hair editor in gloaming"): the raccoon, or any of the
## town's cats, on a turntable, and a panel to change the fur's type (a model of its own for each: FurLook.TYPES),
## what is drawn on it (FurLook.MARKS), a cat's markings (FurLook.PATTERNS) and the colours. What is made is kept
## (FurLook.FILE) and worn in the game when the editor is closed.
##
## Opened over the game from the pause menu (open_over), or alone: godot --path . res://scenes/fur_editor.tscn
##
## Every control is on screen. Drag the figure (mouse or finger) to turn it, or hold the arrows under it; the wheel
## zooms; "Face" and "Whole" frame its head or all of it. Esc or Done closes.

signal closed

## The panel's share of the width on a wide screen (on a tall one it takes the lower part instead).
const PANEL_WIDTH := 0.4
const PANEL_HEIGHT := 0.52
const ACCENT := Color(0.85, 0.6, 0.33)
const CAT_SIZE := 0.85

## The game it was opened over (null alone): what is made is put on its raccoon and cats when it closes.
var world: World
var embedded := false
## What is on the turntable: "raccoon", or "cat" (cat_index of the town's).
var kind := "raccoon"
var cat_index := 0
var look := {}

var _stand: Stand
var _rig: RaccoonRig
var _camera: Camera3D
var _yaw := 0.7
var _pitch := 0.12
var _distance := 2.6
var _face := false
var _spin := 0.0
var _turning := true
var _dragging := false
var _own_colours := {}
var _hero_changed := false
## A slider moved and not yet let go of (kept on letting go, choosing another, or Done).
var _pending := false
var _cats_changed := {}
var _root: Control
var _panel: PanelContainer
var _list: VBoxContainer
var _under: HBoxContainer
var _tab_buttons: Array[Button] = []
## The fur shape's part picked, and the box its sliders are in.
const PART_NAMES := {"all": "All", "back": "Back", "chest": "Chest", "arms": "Arms", "legs": "Legs", "crown": "Crown", "mane": "Mane"}
var _part := "all"
var _part_box: VBoxContainer


## A body for the rig to stand on the turntable (what a rig reads of whoever it poses; nothing moves it).
class Stand extends CharacterBody3D:
	signal jumped
	signal landed(impact_speed: float)
	signal respawned
	var walk_speed := 1.0
	var run_speed := 4.4
	var sprint_speed := 6.2
	var is_pushing := false
	var is_ducking := false
	var is_crawling := false
	var is_sprinting := false
	var air_time := 0.0
	var sit_progress := 0.0


## Opens the editor over the game, which stops under it; `done` is called when it closes.
static func open_over(host: Node, game: World, done: Callable) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 50
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	var holder := SubViewportContainer.new()
	holder.stretch = true
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(holder)
	var view := SubViewport.new()
	view.own_world_3d = true
	view.msaa_3d = Viewport.MSAA_2X
	holder.add_child(view)
	var editor := FurEditor.new()
	editor.world = game
	editor.embedded = true
	view.add_child(editor)
	var tree := host.get_tree()
	var blocked := Player.input_blocked
	Player.input_blocked = true
	tree.paused = true
	tree.root.add_child(layer)
	editor.closed.connect(func() -> void:
		Player.input_blocked = blocked
		layer.queue_free()
		done.call())


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_stage()
	_choose("raccoon", 0)
	_build_panel()
	get_viewport().size_changed.connect(_layout)
	_layout()


func _stage() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.12, 0.13, 0.17)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.55, 0.55, 0.62)
	environment.ambient_light_energy = 0.35
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	add_child(world_environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40.0, 35.0, 0.0)
	sun.light_color = Color(1.0, 0.99, 0.96)
	sun.light_energy = 0.85
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 6.0
	add_child(sun)
	# The turntable: a low round plinth
	var plinth := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 0.75
	disc.bottom_radius = 0.8
	disc.height = 0.08
	plinth.mesh = disc
	plinth.position.y = -0.04
	plinth.material_override = Toon.surface(Color(0.32, 0.28, 0.3))
	add_child(plinth)
	_camera = Camera3D.new()
	_camera.fov = 32.0
	add_child(_camera)
	_camera.make_current()


## Puts a raccoon or cat number `index` on the turntable, in its look.
func _choose(what: String, index: int) -> void:
	if _pending and _rig:
		_keep()
	kind = what
	cat_index = index
	if what == "cat":
		look = FurLook.cat(index)
	else:
		look = FurLook.hero()
	if _stand:
		_stand.queue_free()
	_stand = Stand.new()
	_rig = CatRig.new() if what == "cat" else RaccoonRig.new()
	_rig.name = "Rig"
	if what == "cat":
		_rig.model = load(FurLook.model_path("cat", look.get("fur", "spiky")))
		_rig.scale = Vector3.ONE * CAT_SIZE
	else:
		_rig.model = load("res://models/raccoon.glb")
		_rig.key_poses = false
		_rig.cap_hand = false
	_rig.dusty = false
	_rig.look = look.duplicate(true)
	_stand.add_child(_rig)
	add_child(_stand)
	_own_colours = Toon.colours_of(_rig._figure) if _rig._figure else {}
	_rig.restyle()
	_frame()


func _frame() -> void:
	var tall := 1.05 if kind == "raccoon" else 1.2
	_distance = 1.35 if _face else tall * 2.5


func _process(delta: float) -> void:
	if _turning and not _dragging:
		_yaw += delta * 0.45
	_yaw += _spin * delta * 2.2
	var tall := 1.05 if kind == "raccoon" else 0.55
	var target := Vector3(0.0, tall * (0.88 if _face else 0.5), 0.0)
	# (on a tall screen it has only the part above the panel: further off to fit it)
	var distance := _distance if _wide() else _distance / (1.0 - PANEL_HEIGHT)
	var from := Vector3(sin(_yaw) * cos(_pitch), sin(_pitch), cos(_yaw) * cos(_pitch)) * distance
	_camera.look_at_from_position(target + from, target)
	# (the figure in the middle of what the panel leaves: to its right on a wide screen, above it on a tall one)
	var size := get_viewport().get_visible_rect().size
	var span := 2.0 * distance * tan(deg_to_rad(_camera.fov) * 0.5)
	if _wide():
		_camera.h_offset = -PANEL_WIDTH * 0.5 * span * size.aspect()
		_camera.v_offset = 0.0
	else:
		_camera.h_offset = 0.0
		_camera.v_offset = -PANEL_HEIGHT * 0.5 * span


func _wide() -> bool:
	return get_viewport().get_visible_rect().size.aspect() >= 1.0


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_dragging = event.pressed
		if event.pressed:
			_turning = false
	elif event is InputEventScreenTouch:
		_dragging = event.pressed
		_turning = false
	elif (event is InputEventMouseMotion and _dragging) or event is InputEventScreenDrag:
		_yaw -= event.relative.x * 0.01
		_pitch = clampf(_pitch + event.relative.y * 0.006, -0.3, 0.9)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
		_distance = maxf(_distance * 0.88, 0.5)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		_distance = minf(_distance / 0.88, 6.0)
	elif event.is_action_pressed(&"ui_cancel") or (InputMap.has_action(&"pause") and event.is_action_pressed(&"pause")):
		get_viewport().set_input_as_handled()
		_done()


# --- The panel ---

func _build_panel() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_root)
	_panel = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.07, 0.1, 0.92)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	_panel.add_theme_stylebox_override(&"panel", style)
	_root.add_child(_panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 10)
	_panel.add_child(column)
	# What is on the turntable
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override(&"separation", 8)
	column.add_child(tabs)
	var group := ButtonGroup.new()
	_tab_buttons.clear()
	for what: String in ["raccoon", "cat"]:
		var tab := _button(tabs, "Raccoon" if what == "raccoon" else "Cats", func() -> void:
			if kind != what:
				_choose(what, 0)
				_fill())
		tab.toggle_mode = true
		tab.button_group = group
		tab.button_pressed = what == kind
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_tab_buttons.append(tab)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override(&"separation", 10)
	scroll.add_child(_list)
	# Own look and Done, at the foot
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override(&"separation", 10)
	column.add_child(foot)
	var reset := _icon_button(foot, Icon.Kind.UNDO, "Own look", _reset)
	reset.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var done := _icon_button(foot, Icon.Kind.CHECK, "Done", _done)
	done.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Turning and framing, under the figure
	_under = HBoxContainer.new()
	_under.alignment = BoxContainer.ALIGNMENT_CENTER
	_under.add_theme_constant_override(&"separation", 10)
	_root.add_child(_under)
	for way: int in [-1, 1]:
		var turn := Button.new()
		turn.custom_minimum_size = Vector2(64, 56)
		turn.focus_mode = Control.FOCUS_NONE
		var arrow := Icon.make(Icon.Kind.LEFT if way < 0 else Icon.Kind.RIGHT, 36.0)
		arrow.set_anchors_preset(Control.PRESET_FULL_RECT)
		turn.add_child(arrow)
		turn.button_down.connect(func() -> void:
			_spin = way
			_turning = false)
		turn.button_up.connect(func() -> void: _spin = 0.0)
		_under.add_child(turn)
	var framing := _button(_under, "Face", func() -> void: pass)
	framing.custom_minimum_size = Vector2(90, 56)
	framing.pressed.connect(func() -> void:
		_face = not _face
		framing.text = "Whole" if _face else "Face"
		_frame())
	_fill()


## Fills the panel's list for what is on the turntable.
func _fill() -> void:
	for child in _list.get_children():
		child.queue_free()
	if kind == "cat":
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override(&"separation", 12)
		_list.add_child(row)
		var count := _cat_count()
		_arrow(row, Icon.Kind.LEFT, func() -> void:
			_choose("cat", (cat_index + count - 1) % count)
			_fill())
		var which := _label("Cat %d of %d" % [cat_index + 1, count], 20)
		which.custom_minimum_size.x = 130
		which.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		row.add_child(which)
		_arrow(row, Icon.Kind.RIGHT, func() -> void:
			_choose("cat", (cat_index + 1) % count)
			_fill())
	_choices("Fur", FurLook.CAT_TYPES if kind == "cat" else FurLook.TYPES, "fur", "spiky")
	if kind == "raccoon":
		# (each spike's own shape: the user, "why is there not any fur shape options beside triangle")
		_choices("Shape", FurLook.SHAPES, "shape", "triangle")
	_choices("Texture", FurLook.TEXTURES, "texture", "solid")
	_choices("Drawn on the fur", FurLook.MARKS, "marks", "plain")
	if kind == "raccoon":
		# (live, in the fur shader: FurLook; the user, "I should be able to control the angle of the fur and how
		# dense, and the ring mane as well", "and the fur length")
		# (and by part: "I should be able to control the width and size of each fur blade, and the density on
		# different body parts")
		_list.add_child(_label("Fur shape", 22, ACCENT))
		var picks := GridContainer.new()
		picks.columns = 4
		picks.add_theme_constant_override(&"h_separation", 6)
		picks.add_theme_constant_override(&"v_separation", 6)
		_list.add_child(picks)
		_part_box = VBoxContainer.new()
		_part_box.add_theme_constant_override(&"separation", 6)
		_list.add_child(_part_box)
		var group := ButtonGroup.new()
		for part: String in PART_NAMES:
			var pick := _button(picks, PART_NAMES[part], func() -> void:
				_part = part
				_fill_part())
			pick.toggle_mode = true
			pick.button_group = group
			pick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			pick.set_pressed_no_signal(part == _part)
		_fill_part()
	# ("I should be able to control tail length and thickness as well")
	_list.add_child(_label("Tail", 22, ACCENT))
	_shape_slider("tail", FurLook.TAIL_SHAPE, 0, "Length", 0.5, 1.8)
	if kind == "raccoon":
		_shape_slider("tail", FurLook.TAIL_SHAPE, 1, "Thickness", 0.5, 2.0)
	if kind == "cat":
		_choices("Markings", FurLook.PATTERNS, "pattern", "none")
	_list.add_child(_label("Colours", 22, ACCENT))
	for pair: Array in FurLook.COLOURS[kind]:
		_colour_row(pair[0], pair[1])


## The fur shape's sliders for the part picked: all of it (length, angle, density), the mane (count, length, width,
## angle), or one part (size, width, density).
func _fill_part() -> void:
	for child in _part_box.get_children():
		child.queue_free()
	if _part == "all":
		_shape_slider("body", FurLook.BODY_SHAPE, 0, "Length", 0.3, 2.2, _part_box)
		_shape_slider("body", FurLook.BODY_SHAPE, 1, "Angle", -0.9, 0.9, _part_box)
		_shape_slider("body", FurLook.BODY_SHAPE, 2, "Density", 0.0, 1.0, _part_box)
	elif _part == "mane":
		_shape_slider("mane", FurLook.MANE_SHAPE, 2, "Count", 0.0, 1.0, _part_box)
		_shape_slider("mane", FurLook.MANE_SHAPE, 0, "Length", 0.3, 2.6, _part_box)
		_shape_slider("mane", FurLook.MANE_SHAPE, 3, "Width", 0.3, 2.6, _part_box)
		_shape_slider("mane", FurLook.MANE_SHAPE, 1, "Angle", -0.9, 0.9, _part_box)
	else:
		_shape_slider("parts", FurLook.PART_SHAPE, 0, "Size", 0.2, 2.4, _part_box, _part)
		_shape_slider("parts", FurLook.PART_SHAPE, 1, "Width", 0.3, 3.0, _part_box, _part)
		_shape_slider("parts", FurLook.PART_SHAPE, 2, "Density", 0.0, 1.0, _part_box, _part)


## A heading and a grid of buttons, one of them pressed: the look's `key`.
func _choices(heading: String, options: Array, key: String, own: String) -> void:
	_list.add_child(_label(heading, 22, ACCENT))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override(&"h_separation", 8)
	grid.add_theme_constant_override(&"v_separation", 8)
	_list.add_child(grid)
	var group := ButtonGroup.new()
	for option: String in options:
		var button := _button(grid, FurLook.NAMES.get(option, option), func() -> void:
			look[key] = option
			# (a fur shape other than the triangle is built at the plain fur type, and a fur type with triangles)
			var other := ""
			if key == "shape" and option != "triangle" and look.get("fur", "spiky") != "spiky":
				look["fur"] = "spiky"
				other = "fur"
			elif key == "fur" and option != "spiky" and look.get("shape", "triangle") != "triangle":
				look["shape"] = "triangle"
				other = "shape"
			_changed()
			if other != "":
				_fill.call_deferred())
		button.toggle_mode = true
		button.button_group = group
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.set_pressed_no_signal(look.get(key, own) == option)


## One colour: its name, a swatch, and sliders for its hue, richness and lightness.
func _colour_row(material: String, named: String) -> void:
	var colours: Dictionary = look.get("colours", {})
	var colour: Color = colours.get(material, _own_colours.get(material, Color(0.5, 0.5, 0.5)))
	var head := HBoxContainer.new()
	head.add_theme_constant_override(&"separation", 10)
	_list.add_child(head)
	var swatch := ColorRect.new()
	swatch.color = colour
	swatch.custom_minimum_size = Vector2(34, 26)
	head.add_child(swatch)
	head.add_child(_label(named, 18))
	var sliders: Array[HSlider] = []
	for part: String in ["Hue", "Richness", "Lightness"]:
		var row := HBoxContainer.new()
		row.add_theme_constant_override(&"separation", 8)
		_list.add_child(row)
		var name := _label(part, 15, Color(1, 1, 1, 0.7))
		name.custom_minimum_size.x = 92
		row.add_child(name)
		var slider := HSlider.new()
		slider.min_value = 0.0
		slider.max_value = 1.0
		slider.step = 0.005
		slider.custom_minimum_size = Vector2(120, 32)
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.focus_mode = Control.FOCUS_NONE
		slider.value = [colour.h, colour.s, colour.v][sliders.size()]
		row.add_child(slider)
		sliders.append(slider)
	for slider in sliders:
		slider.value_changed.connect(func(_value: float) -> void:
			var made := Color.from_hsv(sliders[0].value, sliders[1].value, sliders[2].value)
			swatch.color = made
			var now: Dictionary = look.get("colours", {})
			now[material] = made
			look["colours"] = now
			_changed())


## One number of the look's `key` (an Array, `own` where it has none), at `index`, on a slider; changed live (only the
## shader's numbers and the tail's: no new mesh), kept when let go.
## (`part`: a part of look "parts", by name, rather than the look's `key` itself)
func _shape_slider(key: String, own: Array, index: int, named: String, low: float, high: float, parent: Control = null, part := "") -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 8)
	(parent if parent else _list).add_child(row)
	var name := _label(named, 15, Color(1, 1, 1, 0.7))
	name.custom_minimum_size.x = 92
	row.add_child(name)
	var slider := HSlider.new()
	slider.min_value = low
	slider.max_value = high
	slider.step = 0.01
	slider.custom_minimum_size = Vector2(120, 32)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.focus_mode = Control.FOCUS_NONE
	var parts: Dictionary = look.get("parts", {})
	slider.value = float(((parts.get(part, own) if part != "" else look.get(key, own)) as Array)[index])
	row.add_child(slider)
	slider.value_changed.connect(func(value: float) -> void:
		if part != "":
			var all: Dictionary = (look.get("parts", {}) as Dictionary).duplicate(true)
			var now: Array = (all.get(part, own) as Array).duplicate()
			now[index] = value
			all[part] = now
			look["parts"] = all
		else:
			var now: Array = (look.get(key, own) as Array).duplicate()
			now[index] = value
			look[key] = now
		_changed(true))
	slider.drag_ended.connect(func(_moved: bool) -> void: _keep())


func _changed(light := false) -> void:
	_rig.look = look.duplicate(true)
	if light:
		FurLook.paint(_rig)
		_pending = true
	else:
		_rig.restyle()
		_keep()


func _keep() -> void:
	_pending = false
	if kind == "cat":
		FurLook.set_cat(cat_index, look)
		_cats_changed[cat_index] = true
	else:
		FurLook.set_hero(look)
		_hero_changed = true


func _reset() -> void:
	FurLook.forget(kind, cat_index)
	if kind == "cat":
		_cats_changed[cat_index] = true
	else:
		_hero_changed = true
	_choose(kind, cat_index)
	_fill()


## How many cats there are to choose among: the town's, or the looks there are.
func _cat_count() -> int:
	var count := 0
	if world:
		count = world.get_tree().get_nodes_in_group(&"cats").filter(func(node: Node) -> bool: return node is YardCat).size()
	return maxi(count, FurLook.CAT_LOOKS.size())


func _done() -> void:
	if _pending:
		_keep()
	if world:
		_wear_in(world)
	if embedded:
		closed.emit()
	else:
		get_tree().quit()


## Puts what was made on the game's raccoon and cats.
static func wear_all(game: World) -> void:
	var rig := game.player.get_node_or_null(^"Rig") as RaccoonRig
	if rig:
		var hero := FurLook.hero()
		var own: Dictionary = rig.get_meta(&"own_look", rig.look)
		rig.set_meta(&"own_look", own)
		rig.look = hero if not hero.is_empty() else own
		rig.restyle()
	for node in game.get_tree().get_nodes_in_group(&"cats"):
		var cat := node as YardCat
		if cat and cat.rig:
			cat.rig.look = FurLook.cat(cat.index)
			cat.rig.restyle()


func _wear_in(game: World) -> void:
	if _hero_changed or not _cats_changed.is_empty():
		wear_all(game)


func _layout() -> void:
	if _panel == null:
		return
	# (on a tall screen the canvas is as wide as a desktop one, so the panel is drawn bigger to be read on a phone)
	var seen := get_viewport().get_visible_rect().size
	var zoom := 1.0 if _wide() else clampf(seen.x / 560.0, 1.0, 3.0)
	_root.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_root.scale = Vector2.ONE * zoom
	_root.size = seen / zoom
	if _wide():
		_panel.anchor_left = 0.0
		_panel.anchor_top = 0.0
		_panel.anchor_right = PANEL_WIDTH
		_panel.anchor_bottom = 1.0
		_under.anchor_left = PANEL_WIDTH
		_under.anchor_right = 1.0
		_under.anchor_top = 1.0
		_under.anchor_bottom = 1.0
		_under.offset_top = -76
		_under.offset_bottom = -16
	else:
		_panel.anchor_left = 0.0
		_panel.anchor_top = 1.0 - PANEL_HEIGHT
		_panel.anchor_right = 1.0
		_panel.anchor_bottom = 1.0
		_under.anchor_left = 0.0
		_under.anchor_right = 1.0
		_under.anchor_top = 1.0 - PANEL_HEIGHT
		_under.anchor_bottom = 1.0 - PANEL_HEIGHT
		_under.offset_top = -70
		_under.offset_bottom = -10
	for control: Control in [_panel, _under]:
		control.offset_left = 0
		control.offset_right = 0
	_panel.offset_top = 0
	_panel.offset_bottom = 0


# --- Small parts ---

func _label(text: String, size: int, colour := Color.WHITE) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override(&"font_size", size)
	label.add_theme_color_override(&"font_color", colour)
	return label


func _button(parent: Control, text: String, pressed: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 44)
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override(&"font_size", 17)
	button.pressed.connect(pressed)
	parent.add_child(button)
	return button


func _icon_button(parent: Control, what: Icon.Kind, words: String, pressed: Callable) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(0, 64)
	button.focus_mode = Control.FOCUS_NONE
	button.tooltip_text = words
	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(Icon.make(what, 38.0))
	var label := _label(words, 18)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(label)
	button.add_child(row)
	button.pressed.connect(pressed)
	parent.add_child(button)
	return button


func _arrow(parent: Control, what: Icon.Kind, pressed: Callable) -> void:
	var button := Button.new()
	button.custom_minimum_size = Vector2(56, 48)
	button.focus_mode = Control.FOCUS_NONE
	var symbol := Icon.make(what, 30.0)
	symbol.set_anchors_preset(Control.PRESET_FULL_RECT)
	button.add_child(symbol)
	button.pressed.connect(pressed)
	parent.add_child(button)
