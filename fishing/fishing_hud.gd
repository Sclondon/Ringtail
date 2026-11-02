class_name FishingHud
extends Control
## Fishing's panel at the top of the screen (its title, and `lines` under it) and its buttons at the bottom right
## (`buttons`: each [id, symbol (FishingButton.Symbol), a key's name or ""]). Every control is on screen; keys are only
## shortcuts (the game reads those itself). Pressing a button emits `pressed(id)`; whether one is held down is
## `held(id)`. From Gloaming's MinigameHud (GameCommon godot/fishing); drawn in the project's own font.

signal pressed(button: String)
signal released(button: String)

var title := ""
var lines: Array = []
var _buttons := {}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_buttons([["quit", FishingButton.Symbol.CROSS, ""]])
	resized.connect(_lay_out)


## Sets the buttons (the quit button is always added last if it is not there).
func set_buttons(list: Array) -> void:
	for b: FishingButton in _buttons.values():
		b.queue_free()
	_buttons.clear()
	var all := list.duplicate()
	if not all.any(func(e: Array) -> bool: return e[0] == "quit"):
		all.append(["quit", FishingButton.Symbol.CROSS, ""])
	for entry: Array in all:
		var b := FishingButton.new()
		b.symbol = entry[1]
		b.key = entry[2]
		var button_id: String = entry[0]
		b.pressed.connect(func() -> void: pressed.emit(button_id))
		b.released.connect(func() -> void: released.emit(button_id))
		add_child(b)
		_buttons[button_id] = b
	_lay_out()


## Changes the symbol on button `button`.
func show_symbol(button: String, symbol: int) -> void:
	if _buttons.has(button):
		(_buttons[button] as FishingButton).symbol = symbol
		(_buttons[button] as FishingButton).queue_redraw()


func held(button: String) -> bool:
	return _buttons.has(button) and (_buttons[button] as FishingButton).down


func _lay_out() -> void:
	var unit := minf(size.x, size.y) / 720.0 * 100.0
	var i := 0
	var ids := _buttons.keys()
	ids.reverse()
	for button_id: String in ids:
		var b: FishingButton = _buttons[button_id]
		var r := unit * (0.42 if button_id == "quit" else 0.62)
		b.size = Vector2(r, r) * 2.0
		# (the quit button small at the top right; the others big along the bottom right, the main one last)
		if button_id == "quit":
			b.position = Vector2(size.x - r * 2.0 - unit * 0.25, unit * 1.3)
		else:
			b.position = Vector2(size.x - (i + 1) * (r * 2.0 + unit * 0.2) - unit * 2.4, size.y - r * 2.0 - unit * 0.45)
			i += 1


func _draw() -> void:
	var unit := minf(size.x, size.y) / 720.0 * 100.0
	if unit < 8.0:
		return
	var font := get_theme_default_font()
	var wide := unit * 6.6
	var tall := unit * (0.62 + 0.42 * lines.size())
	# (below where the game says things)
	var at := Vector2((size.x - wide) * 0.5, unit * 1.05)
	draw_rect(Rect2(at, Vector2(wide, tall)), Color(0.05, 0.04, 0.03, 0.72))
	draw_rect(Rect2(at, Vector2(wide, tall)), Color(0.85, 0.66, 0.3, 0.9), false, 2.0)
	draw_string(font, at + Vector2(0.0, unit * 0.45), title, HORIZONTAL_ALIGNMENT_CENTER, wide, int(unit * 0.32), Color(1.0, 0.86, 0.5))
	for k in lines.size():
		draw_string(font, at + Vector2(0.0, unit * (0.85 + 0.42 * k)), str(lines[k]), HORIZONTAL_ALIGNMENT_CENTER, wide, int(unit * 0.28), Color(1.0, 0.97, 0.9))
