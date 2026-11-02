class_name Hud
extends CanvasLayer
## Hearts, the Crumb and Bottlecap counts, the race clock, messages, and every
## control as an on-screen button (keys are only shortcuts, shown small under each
## symbol): duck, sprint, tail and jump. On a phone the touch controls (stick, jump,
## duck, sprint) are TouchControls', and only the tail button is added here.

var world: World

var _hearts: HBoxContainer
var _crumbs: Label
var _caps: Label
var _kits: Label
var _zone: Label
var _clock_row: HBoxContainer
var _clock: Label
var _message: Label
var _message_t := 0.0
var _buttons: HBoxContainer
var _tail_touch: Button
## The buttons' symbols, by action (swapped playing as a bird).
var _icons := {}
var _dev: VBoxContainer
var pause: PauseMenu


func _ready() -> void:
	layer = 2
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var top_left := VBoxContainer.new()
	top_left.position = Vector2(22, 16)
	top_left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(top_left)
	_hearts = HBoxContainer.new()
	_hearts.add_theme_constant_override(&"separation", 6)
	top_left.add_child(_hearts)
	# (which side of the hill he is on: its own food and kits are counted below; in the grove, the whole hill's)
	_zone = _label(24, Color(1.0, 0.94, 0.8))
	top_left.add_child(_zone)
	_crumbs = _counter(top_left, Icon.Kind.CRUMB, Color(0.85, 0.6, 0.33))
	# (the lost kits led home, when there are any to find)
	_kits = _counter(top_left, Icon.Kind.KIT, Color(0.9, 0.88, 0.84))
	if world.lost_kits and world.lost_kits.total > 0:
		world.lost_kits.changed.connect(func(_home: int, _total: int) -> void: _show_counts())
	else:
		_kits.get_parent().visible = false
	if world.zones:
		world.zones.changed.connect(_show_counts)
	_show_counts.call_deferred()

	var top_right := HBoxContainer.new()
	top_right.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	top_right.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	top_right.offset_right = -22
	top_right.offset_top = 16
	root.add_child(top_right)
	_caps = _counter(top_right, Icon.Kind.CAP, Color(0.98, 0.78, 0.25))
	# The pause button, always on screen (Esc, P or Start too): the pause screen and the model editor (the user,
	# 2026-11-02: "Give me a pause screen and model editor")
	pause = PauseMenu.new()
	pause.world = world
	add_child(pause)
	var stop := Button.new()
	stop.custom_minimum_size = Vector2(64, 64)
	stop.focus_mode = Control.FOCUS_NONE
	stop.tooltip_text = "Pause (Esc)"
	var bars := Icon.make(Icon.Kind.PAUSE, 40.0)
	bars.set_anchors_preset(Control.PRESET_FULL_RECT)
	stop.add_child(bars)
	stop.pressed.connect(pause.open)
	top_right.add_child(stop)
	# (the look last made in the editor, on him from the start)
	FurEditor.wear_all.call_deferred(world)

	_clock_row = HBoxContainer.new()
	_clock_row.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_clock_row.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_clock_row.offset_top = 14
	root.add_child(_clock_row)
	_clock = _counter(_clock_row, Icon.Kind.CLOCK, Color(0.6, 0.95, 1.0))

	_message = _label(26, Color.WHITE)
	_message.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.offset_left = -420
	_message.offset_right = 420
	_message.offset_top = -170
	_message.offset_bottom = -130
	root.add_child(_message)

	_buttons = HBoxContainer.new()
	_buttons.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_buttons.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_buttons.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_buttons.offset_right = -20
	_buttons.offset_bottom = -20
	_buttons.add_theme_constant_override(&"separation", 12)
	root.add_child(_buttons)
	_button(Icon.Kind.DUCK, "C", &"duck")
	_button(Icon.Kind.SCURRY, "Shift", &"scurry")
	_button(Icon.Kind.TAIL, "E", &"tail")
	_button(Icon.Kind.JUMP, "Space", &"jump")

	# On a phone: the tail button, above the touch controls' own jump.
	_tail_touch = Button.new()
	_tail_touch.custom_minimum_size = Vector2(110, 110)
	_tail_touch.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_tail_touch.offset_left = -150
	_tail_touch.offset_top = -420
	_tail_touch.offset_right = -40
	_tail_touch.offset_bottom = -310
	_tail_touch.focus_mode = Control.FOCUS_NONE
	_tail_touch.button_down.connect(_tail)
	var spiral := Icon.make(Icon.Kind.TAIL, 64.0)
	spiral.set_anchors_preset(Control.PRESET_FULL_RECT)
	_tail_touch.add_child(spiral)
	root.add_child(_tail_touch)

	if OS.has_feature("editor") or "--dev" in OS.get_cmdline_user_args() or _web_dev():
		_dev_panel(root)

	world.crumbs_changed.connect(func(_count: int, _total: int) -> void: _show_counts())
	world.caps_changed.connect(func(count: int, total: int) -> void: _caps.text = "%d / %d" % [count, total])
	world.hearts_changed.connect(_show_hearts)
	world.said.connect(say)


## The food and kit counts: the zone he is in (Zones), or the whole hill's in the grove (the user, 2026-11-02:
## "each zone should ... have different kit and food trackers").
func _show_counts() -> void:
	var zones := world.zones
	var zone := zones.current if zones else -1
	if zone >= 0:
		_zone.text = zones.names[zone]
		_crumbs.text = "%d / %d" % [zones.food[zone], zones.food_total[zone]]
		_kits.text = "%d / %d" % [zones.kits[zone], zones.kits_total[zone]]
	else:
		_zone.text = "The grove" if zones and not zones.names.is_empty() else ""
		_crumbs.text = "%d / %d" % [world.crumbs, world.crumbs_total]
		if world.lost_kits:
			_kits.text = "%d / %d" % [world.lost_kits.found, world.lost_kits.total]
	_zone.visible = _zone.text != ""


func _web_dev() -> bool:
	return OS.has_feature("web") and str(JavaScriptBridge.eval("location.search")).contains("dev")


func _label(size: int, colour: Color) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override(&"font_size", size)
	label.add_theme_color_override(&"font_color", colour)
	label.add_theme_color_override(&"font_outline_color", Color(0.08, 0.05, 0.1))
	label.add_theme_constant_override(&"outline_size", 8)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _counter(parent: Control, what: Icon.Kind, colour: Color) -> Label:
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(Icon.make(what, 40.0, colour))
	var label := _label(30, colour)
	row.add_child(label)
	parent.add_child(row)
	return label


func _show_hearts(count: int) -> void:
	for child in _hearts.get_children():
		child.queue_free()
	for k in World.MAX_HEARTS:
		_hearts.add_child(Icon.make(Icon.Kind.HEART if k < count else Icon.Kind.HEART_EMPTY, 38.0, Color(1.0, 0.3, 0.38)))


func _button(what: Icon.Kind, key: String, action: StringName) -> void:
	var button := Button.new()
	button.custom_minimum_size = Vector2(88, 88)
	button.focus_mode = Control.FOCUS_NONE
	var symbol := Icon.make(what, 46.0)
	symbol.set_anchors_preset(Control.PRESET_FULL_RECT)
	symbol.offset_bottom = -18
	button.add_child(symbol)
	_icons[action] = symbol
	var shortcut := _label(14, Color(1, 1, 1, 0.7))
	shortcut.text = key
	shortcut.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	shortcut.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	shortcut.offset_left = -40
	shortcut.offset_right = 40
	shortcut.offset_top = -22
	shortcut.add_theme_constant_override(&"outline_size", 4)
	button.add_child(shortcut)
	button.button_down.connect(func() -> void: _press(action, true))
	button.button_up.connect(func() -> void: _press(action, false))
	_buttons.add_child(button)


func _press(action: StringName, down: bool) -> void:
	# (playing as a bird: its own, the same buttons: flap, dive, settle, peck)
	var bird := BirdPlayer.active(world)
	if bird:
		bird.press(action, down)
		return
	if action == &"scurry":
		var scurry := world.player.get_node_or_null(^"Scurry") as Scurry
		if scurry:
			scurry.button = down
		return
	if action == &"tail":
		if down:
			_tail()
		return
	if down:
		Input.action_press(action)
		if action == &"jump":
			world.player._queue_jump()
	else:
		Input.action_release(action)


func _tail() -> void:
	var bird := BirdPlayer.active(world)
	if bird:
		bird.press(&"tail", true)
		return
	var moves := world.player.get_node_or_null(^"TailMoves") as TailMoves
	if moves:
		moves.press()


func say(text: String) -> void:
	_message.text = text
	_message_t = 3.0


func _process(delta: float) -> void:
	_message_t -= delta
	_message.modulate.a = clampf(_message_t, 0.0, 1.0)
	# (the raccoon's scurry and tail are a bird's settle and peck: BirdPlayer)
	var as_bird := BirdPlayer.active(world) != null
	for pair: Array in [[&"scurry", Icon.Kind.SCURRY, Icon.Kind.PERCH], [&"tail", Icon.Kind.TAIL, Icon.Kind.PECK]]:
		var icon: Icon = _icons.get(pair[0])
		var wanted: Icon.Kind = pair[2] if as_bird else pair[1]
		if icon and icon.kind != wanted:
			icon.kind = wanted
			icon.queue_redraw()
	var touch := TouchControls.wanted()
	_buttons.visible = not touch
	_tail_touch.visible = touch
	var racing := world.race != null and world.race.running
	_clock_row.visible = racing
	if racing:
		_clock.text = "%.1f   ·   %d left" % [maxf(world.race.left, 0.0), world.race.remaining()]


## For testing (in the editor, with --dev, or ?dev on the web): a jump to each Bottlecap. (The pixel filter is the
## pause screen's Pixels dial.)
func _dev_panel(root: Control) -> void:
	_dev = VBoxContainer.new()
	_dev.position = Vector2(22, 215)
	root.add_child(_dev)
	for name: String in World.CAP_NAMES:
		var go := Button.new()
		go.text = "Go: " + name
		go.focus_mode = Control.FOCUS_NONE
		go.pressed.connect(func() -> void:
			var at: Transform3D = world.markers.get("cap_" + name, Transform3D.IDENTITY)
			world.player.global_position = at.origin + Vector3(0.0, 0.3, 1.2)
			world.player.velocity = Vector3.ZERO)
		_dev.add_child(go)
