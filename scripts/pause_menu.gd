class_name PauseMenu
extends CanvasLayer
## The pause screen (the user, 2026-11-02: "Give me a pause screen and model editor ..."): the game stops under a
## dark veil, and two buttons: go on, and the model editor (FurEditor), which opens over it and comes back to it.
## Opened by the pause button on the HUD (always on screen), Esc or P, or Start on a pad; the same again goes on.

signal opened
signal closed

var world: World
var _veil: Control
var _editing := false
## The main card, and the page of animals to play that takes its place.
var _card: Control
var _zoo: Control
var _grid: GridContainer


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not InputMap.has_action(&"pause"):
		InputMap.add_action(&"pause")
		for key: Key in [KEY_ESCAPE, KEY_P]:
			var press := InputEventKey.new()
			press.physical_keycode = key
			InputMap.action_add_event(&"pause", press)
		var start := InputEventJoypadButton.new()
		start.button_index = JOY_BUTTON_START
		InputMap.action_add_event(&"pause", start)
	_veil = ColorRect.new()
	(_veil as ColorRect).color = Color(0.02, 0.05, 0.035, 0.6)
	_veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_veil)
	# (everything on a card in the middle: UiStyle "Card")
	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	_veil.add_child(centre)
	var card := PanelContainer.new()
	card.theme_type_variation = &"Card"
	centre.add_child(card)
	var middle := VBoxContainer.new()
	middle.alignment = BoxContainer.ALIGNMENT_CENTER
	middle.add_theme_constant_override(&"separation", 22)
	card.add_child(middle)
	var title := Label.new()
	title.text = "Paused"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override(&"font_size", 46)
	title.add_theme_color_override(&"font_color", UiStyle.AMBER.lerp(UiStyle.CREAM, 0.35))
	title.add_theme_constant_override(&"outline_size", 10)
	middle.add_child(title)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override(&"separation", 28)
	middle.add_child(row)
	_big(row, Icon.Kind.PLAY, "Go on", close)
	_big(row, Icon.Kind.COMB, "Fur & looks", _edit)
	# The pixel filter's dial: off at the left, chunkiest at the right (the user, 2026-11-02, "it should be in the
	# pause screen with a dial"; it was a switch on the testing panel)
	var dial := HBoxContainer.new()
	dial.alignment = BoxContainer.ALIGNMENT_CENTER
	dial.add_theme_constant_override(&"separation", 18)
	middle.add_child(dial)
	var named := Label.new()
	named.text = "Pixels"
	named.add_theme_font_size_override(&"font_size", 24)
	named.add_theme_color_override(&"font_color", UiStyle.MOSS.lerp(UiStyle.CREAM, 0.4))
	dial.add_child(named)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.01
	slider.value = N64Filter.strength
	slider.custom_minimum_size = Vector2(320, 40)
	slider.focus_mode = Control.FOCUS_NONE
	slider.value_changed.connect(N64Filter.set_strength)
	dial.add_child(slider)
	# Who he plays as: the raccoon, the crow or the owl (BirdPlayer; the user, 2026-11-02, "add a mode where you can be
	# the crow or owl")
	var who := HBoxContainer.new()
	who.alignment = BoxContainer.ALIGNMENT_CENTER
	who.add_theme_constant_override(&"separation", 18)
	middle.add_child(who)
	for pick: Array in [[Icon.Kind.KIT, &"raccoon", "Raccoon"], [Icon.Kind.CROW, &"crow", "Crow"], [Icon.Kind.OWL, &"owl", "Owl"]]:
		var as_one := _big(who, pick[0], pick[2], func() -> void:
			BirdPlayer.play_as(world, pick[1])
			close())
		as_one.custom_minimum_size = Vector2(112, 112)
	# (and every other animal, on a page of their own: AnimalPlayer; the user, 2026-11-02, "there should be an option
	# to play as all the animals")
	var more := _big(who, Icon.Kind.SCURRY, "Animals", func() -> void:
		_card.visible = false
		_zoo.visible = true)
	more.custom_minimum_size = Vector2(112, 112)
	_card = card
	_zoo = _animals_page(centre)
	_veil.visible = false


## The page of every animal to play: a grid of their pictures (ui/faces, tools/make_animal_faces.gd), and back.
func _animals_page(parent: Control) -> Control:
	var page := PanelContainer.new()
	page.theme_type_variation = &"Card"
	page.visible = false
	parent.add_child(page)
	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 14)
	page.add_child(column)
	var top := HBoxContainer.new()
	top.add_theme_constant_override(&"separation", 16)
	column.add_child(top)
	var back := Button.new()
	back.custom_minimum_size = Vector2(64, 64)
	back.focus_mode = Control.FOCUS_NONE
	back.tooltip_text = "Back"
	var arrow := Icon.make(Icon.Kind.LEFT, 40.0, UiStyle.CREAM)
	arrow.set_anchors_preset(Control.PRESET_FULL_RECT)
	back.add_child(arrow)
	back.pressed.connect(func() -> void:
		page.visible = false
		_card.visible = true)
	top.add_child(back)
	var title := Label.new()
	title.text = "Play as"
	title.add_theme_font_size_override(&"font_size", 34)
	title.add_theme_color_override(&"font_color", UiStyle.AMBER.lerp(UiStyle.CREAM, 0.35))
	title.add_theme_constant_override(&"outline_size", 8)
	top.add_child(title)
	var grid := GridContainer.new()
	grid.columns = 7
	_grid = grid
	grid.add_theme_constant_override(&"h_separation", 8)
	grid.add_theme_constant_override(&"v_separation", 8)
	column.add_child(grid)
	for what: String in AnimalPlayer.ANIMALS:
		var tile := Button.new()
		tile.custom_minimum_size = Vector2(96, 96)
		tile.focus_mode = Control.FOCUS_NONE
		var words := what.replace("_", " ").capitalize()
		tile.tooltip_text = words
		var face_path := "res://ui/faces/%s.png" % what
		if ResourceLoader.exists(face_path):
			var face := TextureRect.new()
			face.texture = load(face_path)
			face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			face.set_anchors_preset(Control.PRESET_FULL_RECT)
			face.offset_left = 6
			face.offset_top = 4
			face.offset_right = -6
			face.offset_bottom = -18
			face.mouse_filter = Control.MOUSE_FILTER_IGNORE
			tile.add_child(face)
		var label := Label.new()
		label.text = words
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
		label.offset_left = -48
		label.offset_right = 48
		label.offset_top = -22
		label.offset_bottom = -4
		label.add_theme_font_size_override(&"font_size", 13)
		label.add_theme_constant_override(&"outline_size", 4)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tile.add_child(label)
		tile.pressed.connect(func() -> void:
			BirdPlayer.play_as(world, StringName(what))
			page.visible = false
			_card.visible = true
			close())
		grid.add_child(tile)
	return page


## A big button: a symbol, and a word small under it.
func _big(parent: Control, what: Icon.Kind, words: String, pressed: Callable) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(150, 150)
	button.focus_mode = Control.FOCUS_NONE
	button.tooltip_text = words
	var symbol := Icon.make(what, 72.0, UiStyle.CREAM)
	symbol.set_anchors_preset(Control.PRESET_FULL_RECT)
	symbol.offset_bottom = -30
	button.add_child(symbol)
	var label := Label.new()
	label.text = words
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	label.offset_left = -75
	label.offset_right = 75
	label.offset_top = -38
	label.offset_bottom = -8
	label.add_theme_font_size_override(&"font_size", 18)
	label.add_theme_constant_override(&"outline_size", 5)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(label)
	button.pressed.connect(pressed)
	parent.add_child(button)
	return button


func is_open() -> bool:
	return _veil.visible


func open() -> void:
	if is_open() or _editing:
		return
	# (on a tall screen the canvas is as wide as a desktop one: drawn bigger, to be read and pressed on a phone)
	var seen := get_viewport().get_visible_rect().size
	var zoom := 1.0 if seen.aspect() >= 1.0 else clampf(seen.x / 560.0, 1.0, 3.0)
	scale = Vector2.ONE * zoom
	_veil.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_veil.size = seen / zoom
	_veil.visible = true
	_card.visible = true
	_zoo.visible = false
	get_tree().paused = true
	# (four across on a tall screen, seven on a wide one)
	_grid.columns = 7 if seen.aspect() >= 1.0 else 4
	opened.emit()


func close() -> void:
	if not is_open():
		return
	_veil.visible = false
	get_tree().paused = false
	closed.emit()


func toggle() -> void:
	if is_open():
		close()
	else:
		open()


func _unhandled_input(event: InputEvent) -> void:
	if _editing or not event.is_action_pressed(&"pause") or event.is_echo():
		return
	# (not while someone is talking to him: Esc is theirs then)
	if not is_open() and get_tree().paused:
		return
	get_viewport().set_input_as_handled()
	toggle()


func _edit() -> void:
	_editing = true
	_veil.visible = false
	FurEditor.open_over(self, world, func() -> void:
		_editing = false
		_veil.visible = true)
