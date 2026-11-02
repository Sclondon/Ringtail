class_name TalkBox
extends CanvasLayer
## Talking to the other raccoons (Villagers), as in Gloaming (the user, 2026-11-02: "The talking should work like
## in gloaming not like this"; ported from Gloaming's Story): near one with something to say, "Talk to <name>"
## shows at the bottom of the screen (click it, T, or RB on a gamepad). The talk box is Breath of the Wild's: a dark
## see-through pill low in the middle, the speaker's name small over its top left corner, the words typed out (a
## press shows the rest, the next goes on), a ▶ at its right end that goes on. T, RB, A, Space or Enter go on too.
## He stands still while it shows (Player.input_blocked).
##
## Anyone to talk to is in the group `talkers` with `display_name`, `lines` (an Array of Strings), `in_reach(hero)`
## and `listen(on)` (Villager).

## How many letters a second the words are typed out at; a press while it types shows the rest at once.
const TYPE_SPEED := 45.0
## The gamepad button that talks (Y is duck here, A jump, B the tail, X duck, LT scurry), and the key.
const PAD := JOY_BUTTON_RIGHT_SHOULDER
const KEY := KEY_T

var villagers: Villagers
## Who is being talked to (null: nobody).
var talking: Node3D

var _lines: Array = []
var _line := 0
var _typed := 0.0
var _ui: Control
var _prompt: Button
var _box: PanelContainer
var _speaker: Label
var _text: Label


func _ready() -> void:
	layer = 4
	_ui = Control.new()
	_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_ui)
	_prompt = Button.new()
	_prompt.add_theme_font_size_override(&"font_size", 24)
	_prompt.custom_minimum_size = Vector2(320.0, 50.0)
	_prompt.focus_mode = Control.FOCUS_NONE
	_prompt.pressed.connect(press)
	_prompt.visible = false
	_ui.add_child(_prompt)
	# (Breath of the Wild's talk box, as Gloaming's: a dark see-through pill, no rim, white words)
	_box = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.02, 0.02, 0.7)
	style.set_corner_radius_all(64)
	style.corner_detail = 16
	style.content_margin_left = 64.0
	style.content_margin_right = 30.0
	style.content_margin_top = 20.0
	style.content_margin_bottom = 20.0
	_box.add_theme_stylebox_override(&"panel", style)
	_box.visible = false
	_box.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed or event is InputEventScreenTouch and event.pressed:
			_next())
	_ui.add_child(_box)
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 16)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_child(row)
	_text = Label.new()
	_text.add_theme_font_size_override(&"font_size", 26)
	_text.add_theme_color_override(&"font_color", Color(0.96, 0.96, 0.94))
	_text.add_theme_constant_override(&"line_spacing", 4)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# (three lines high whatever is typed so far: it does not grow as the words come)
	_text.custom_minimum_size = Vector2(0.0, 102.0)
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_text)
	var next := Button.new()
	next.text = "▶"
	next.flat = true
	next.focus_mode = Control.FOCUS_NONE
	next.add_theme_font_size_override(&"font_size", 20)
	next.add_theme_color_override(&"font_color", Color(1.0, 1.0, 1.0, 0.85))
	next.size_flags_vertical = Control.SIZE_SHRINK_END
	next.pressed.connect(_next)
	row.add_child(next)
	_speaker = Label.new()
	_speaker.add_theme_font_size_override(&"font_size", 23)
	_speaker.add_theme_color_override(&"font_color", Color(0.94, 0.94, 0.92))
	_speaker.add_theme_color_override(&"font_outline_color", Color(0.0, 0.0, 0.0, 0.8))
	_speaker.add_theme_constant_override(&"outline_size", 5)
	_speaker.visible = false
	_ui.add_child(_speaker)


func _process(delta: float) -> void:
	var hero := villagers.player
	var near := _nearest(hero)
	_prompt.visible = near != null and talking == null
	if _prompt.visible:
		_prompt.text = "Talk to %s   (T / RB)" % near.get(&"display_name")
	var w := _ui.size.x
	var h := _ui.size.y
	# (above the hero's buttons, which sit at the bottom right)
	_prompt.position = Vector2((w - _prompt.size.x) * 0.5, h - _prompt.size.y - 40.0)
	_box.size.x = clampf(w * 0.5, minf(w - 40.0, 520.0), 760.0)
	_box.size.y = 0.0
	# (and clear of the hero's buttons along the bottom)
	_box.position = Vector2((w - _box.size.x) * 0.5, h - _box.size.y - maxf(h * 0.05, 130.0))
	_speaker.visible = _box.visible and _speaker.text != ""
	if _box.visible and _text.visible_characters >= 0:
		_typed += delta * TYPE_SPEED
		_text.visible_characters = -1 if int(_typed) >= _text.get_total_character_count() else int(_typed)
	_speaker.position = _box.position + Vector2(48.0, -_speaker.size.y + 4.0)


func _input(event: InputEvent) -> void:
	if get_tree().paused:
		return
	var talk: bool = (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY) \
			or (event is InputEventJoypadButton and event.pressed and event.button_index == PAD)
	if talking != null:
		var on: bool = talk or event.is_action_pressed(&"jump") \
				or (event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_ENTER, KEY_KP_ENTER])
		if on:
			_next()
		if on or event.is_action(&"jump"):
			get_viewport().set_input_as_handled()
	elif talk and _nearest(villagers.player):
		press()
		get_viewport().set_input_as_handled()


## The nearest one in reach of the hero with something to say, or null.
func _nearest(hero: Node3D) -> Node3D:
	if hero == null or not (hero is Player and (hero as Player).state == Player.State.FREE and hero.is_on_floor()):
		return null
	var best: Node3D
	for who: Node3D in get_tree().get_nodes_in_group(&"talkers"):
		if who.call(&"in_reach", hero) and (best == null or who.global_position.distance_to(hero.global_position) < best.global_position.distance_to(hero.global_position)):
			best = who
	return best


## The talk prompt (or T, RB): talks to whoever is nearest; with the box up, goes on.
func press() -> void:
	if talking != null:
		_next()
		return
	var who := _nearest(villagers.player)
	if who == null:
		return
	talking = who
	who.call(&"listen", true)
	_lines = Array(who.get(&"lines"))
	_line = 0
	if _lines.is_empty():
		close()
		return
	Player.input_blocked = true
	_show()


func _show() -> void:
	_speaker.text = talking.get(&"display_name")
	_text.text = _lines[_line]
	_typed = 0.0
	_text.visible_characters = 0
	_box.visible = true


func _next() -> void:
	if talking == null:
		return
	if _text.visible_characters >= 0 and _text.visible_characters < _text.get_total_character_count():
		_text.visible_characters = -1
		return
	_line += 1
	if _line < _lines.size():
		_show()
	else:
		close()


## Puts the box away and lets him go.
func close() -> void:
	if talking and is_instance_valid(talking):
		talking.call(&"listen", false)
	talking = null
	_lines = []
	_box.visible = false
	Player.input_blocked = false
