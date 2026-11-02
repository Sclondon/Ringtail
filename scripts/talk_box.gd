class_name TalkBox
extends CanvasLayer
## Talking to the other raccoons (Villagers). Near one with something to say, a talk button (a speech bubble)
## shows above the hero's buttons; pressed (or T, or RB on a gamepad), its lines come up one at a time in a box at
## the foot of the screen, typed out. The button, the box itself, T and RB each go on to the next line, and after
## the last the box closes. While it is open the hero stands still (Player.input_blocked).

const KEY := KEY_T
const PAD := JOY_BUTTON_RIGHT_SHOULDER
## Letters a second as a line is typed out.
const TYPING := 45.0

var villagers: Villagers
## Who is being talked to (null: nobody), the line on, and how much of it is out.
var talking: Villager
var line := 0
var shown := 0.0

var _prompt: Button
var _box: PanelContainer
var _text: Label
var _near: Villager
## (just closed: a moment before the same press can open it again)
var _rest := 0.0


func _ready() -> void:
	layer = 4
	if not InputMap.has_action(&"talk"):
		InputMap.add_action(&"talk")
		var key := InputEventKey.new()
		key.physical_keycode = KEY
		InputMap.action_add_event(&"talk", key)
		var pad := InputEventJoypadButton.new()
		pad.button_index = PAD
		InputMap.action_add_event(&"talk", pad)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_prompt = Button.new()
	_prompt.custom_minimum_size = Vector2(96, 96)
	_prompt.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_prompt.offset_left = -48
	_prompt.offset_right = 48
	_prompt.offset_top = -330
	_prompt.offset_bottom = -234
	_prompt.focus_mode = Control.FOCUS_NONE
	_prompt.visible = false
	_prompt.pressed.connect(press)
	var bubble := Bubble.new()
	bubble.set_anchors_preset(Control.PRESET_FULL_RECT)
	bubble.offset_bottom = -18
	bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt.add_child(bubble)
	var shortcut := Label.new()
	shortcut.text = "T"
	shortcut.add_theme_font_size_override(&"font_size", 14)
	shortcut.add_theme_color_override(&"font_color", Color(1, 1, 1, 0.7))
	shortcut.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	shortcut.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	shortcut.offset_top = -22
	shortcut.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt.add_child(shortcut)
	root.add_child(_prompt)

	_box = PanelContainer.new()
	_box.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_box.offset_left = -380
	_box.offset_right = 380
	_box.offset_top = -230
	_box.offset_bottom = -126
	_box.visible = false
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.98, 0.95, 0.86)
	style.border_color = Color(0.25, 0.18, 0.14)
	style.set_border_width_all(4)
	style.set_corner_radius_all(22)
	style.content_margin_left = 26
	style.content_margin_right = 16
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	_box.add_theme_stylebox_override(&"panel", style)
	_box.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed or event is InputEventScreenTouch and event.pressed:
			press())
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 16)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_child(row)
	_text = Label.new()
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_text.add_theme_font_size_override(&"font_size", 26)
	_text.add_theme_color_override(&"font_color", Color(0.18, 0.12, 0.1))
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_text)
	# (the on-screen "go on" for the box: an arrow at its right)
	var next := Button.new()
	next.focus_mode = Control.FOCUS_NONE
	next.custom_minimum_size = Vector2(60, 60)
	next.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	next.pressed.connect(press)
	var arrow := Arrow.new()
	arrow.set_anchors_preset(Control.PRESET_FULL_RECT)
	arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	next.add_child(arrow)
	row.add_child(next)
	root.add_child(_box)


## Fits the box to the screen: across the foot of a wide one; on a narrow one (a phone) across the top, out of the
## way of the touch controls.
func _layout() -> void:
	var wide := get_viewport().get_visible_rect().size.x
	var across := minf(760.0, wide - 32.0)
	if wide >= 700.0:
		_box.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
		_box.offset_top = -230
		_box.offset_bottom = -126
	else:
		_box.set_anchors_preset(Control.PRESET_CENTER_TOP)
		_box.offset_top = 120
		_box.offset_bottom = 230
	_box.offset_left = -across * 0.5
	_box.offset_right = across * 0.5


func _process(delta: float) -> void:
	_layout()
	_rest = maxf(_rest - delta, 0.0)
	if talking:
		var whole := talking.lines[line]
		shown = minf(shown + delta * TYPING, whole.length())
		_text.text = whole.substr(0, int(shown))
		if Input.is_action_just_pressed(&"talk"):
			press()
		return
	var hero := villagers.player
	var free := hero.state == Player.State.FREE and hero.is_on_floor() and not Player.input_blocked and _rest <= 0.0
	_near = villagers.talker_near() if free else null
	_prompt.visible = _near != null
	if _near and Input.is_action_just_pressed(&"talk"):
		press()


## The talk button (or T, RB, a tap on the box): starts talking to whoever is near, finishes typing out the line,
## goes on to the next, or closes after the last.
func press() -> void:
	if talking == null:
		if _near == null:
			return
		talking = _near
		line = 0
		shown = 0.0
		talking.listen(true)
		Player.input_blocked = true
		_prompt.visible = false
		_box.visible = true
		return
	if shown < talking.lines[line].length():
		shown = talking.lines[line].length()
		return
	line += 1
	shown = 0.0
	if line >= talking.lines.size():
		close()


func close() -> void:
	if talking:
		talking.listen(false)
	talking = null
	_near = null
	_rest = 0.4
	Player.input_blocked = false
	_box.visible = false


## "Go on": a triangle pointing on.
class Arrow extends Control:
	func _draw() -> void:
		var middle := size * 0.5
		var r := minf(size.x, size.y) * 0.26
		draw_colored_polygon(PackedVector2Array([middle + Vector2(-r * 0.7, -r), middle + Vector2(r, 0.0), middle + Vector2(-r * 0.7, r)]), Color.WHITE)


## A speech bubble with three dots: the talk button's symbol.
class Bubble extends Control:
	func _draw() -> void:
		var middle := size * Vector2(0.5, 0.46)
		var radius := minf(size.x, size.y) * 0.34
		var ink := Color(0.12, 0.08, 0.1)
		var points := PackedVector2Array()
		for k in 32:
			var a := TAU * k / 32.0
			points.append(middle + Vector2(cos(a) * radius * 1.25, sin(a) * radius))
		var tail := PackedVector2Array([middle + Vector2(-radius * 0.5, radius * 0.6), middle + Vector2(-radius * 0.95, radius * 1.45), middle + Vector2(-radius * 0.05, radius * 0.85)])
		draw_colored_polygon(tail, Color.WHITE)
		draw_colored_polygon(points, Color.WHITE)
		for k in 3:
			draw_circle(middle + Vector2((k - 1) * radius * 0.55, 0.0), radius * 0.15, ink)
