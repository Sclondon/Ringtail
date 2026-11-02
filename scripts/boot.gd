class_name Boot
extends CanvasLayer
## The start: a loading screen while World 1 is read in and built (the user, 2026-11-02: "a loading screen is a good
## idea - and also that load time seems very long"). The world is built a step at a time (World.stepwise), the game
## paused meanwhile, the bar filling as it goes and a line saying what it is doing; then the screen fades away.
## The look (UiStyle's wood and fir, the spinning ringed tail, the lines) is Claude's pick.

const WORLD := "res://scenes/world1.tscn"
## How much of the bar reading the world in takes; building it takes the rest.
const READ_SHARE := 0.15

var _bar_fill: ColorRect
var _bar_back: Control
var _what: Label
var _tail: Icon
var _shown := 0.0
var _goal := 0.0
var _world: World
var _reading := false


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	var screen := ColorRect.new()
	screen.color = UiStyle.FIR_DEEP
	screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(screen)
	var middle := VBoxContainer.new()
	middle.set_anchors_preset(Control.PRESET_CENTER)
	middle.grow_horizontal = Control.GROW_DIRECTION_BOTH
	middle.grow_vertical = Control.GROW_DIRECTION_BOTH
	middle.alignment = BoxContainer.ALIGNMENT_CENTER
	middle.add_theme_constant_override(&"separation", 18)
	screen.add_child(middle)
	_tail = Icon.make(Icon.Kind.TAIL, 128.0, UiStyle.CREAM)
	_tail.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_tail.pivot_offset = Vector2(64.0, 64.0)
	middle.add_child(_tail)
	var title := Label.new()
	title.text = "Ringtail"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override(&"font_size", 96)
	title.add_theme_constant_override(&"outline_size", 12)
	middle.add_child(title)
	# (the bar: a bark rim round a dark groove, filling with amber)
	var rim := PanelContainer.new()
	var rim_box := StyleBoxFlat.new()
	rim_box.bg_color = UiStyle.BARK
	rim_box.set_corner_radius_all(12)
	rim_box.set_content_margin_all(5)
	rim.add_theme_stylebox_override(&"panel", rim_box)
	rim.custom_minimum_size = Vector2(560.0, 38.0)
	rim.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	middle.add_child(rim)
	_bar_back = ColorRect.new()
	(_bar_back as ColorRect).color = UiStyle.FIR
	_bar_back.clip_contents = true
	rim.add_child(_bar_back)
	_bar_fill = ColorRect.new()
	_bar_fill.color = UiStyle.AMBER
	_bar_back.add_child(_bar_fill)
	_what = Label.new()
	_what.text = "Unpacking"
	_what.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_what.add_theme_font_size_override(&"font_size", 30)
	_what.modulate = Color(1.0, 1.0, 1.0, 0.8)
	middle.add_child(_what)
	_start.call_deferred()


func _start() -> void:
	# (a couple of frames first, so the screen is up before anything heavy)
	await get_tree().process_frame
	await get_tree().process_frame
	if ResourceLoader.load_threaded_request(WORLD) == OK:
		_reading = true
	else:
		_built_from(load(WORLD) as PackedScene)


func _process(delta: float) -> void:
	_tail.rotation += delta * 5.0
	if _reading:
		var progress := []
		var status := ResourceLoader.load_threaded_get_status(WORLD, progress)
		if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			_goal = READ_SHARE * float(progress[0] if not progress.is_empty() else 0.0)
		else:
			_reading = false
			_built_from(ResourceLoader.load_threaded_get(WORLD) as PackedScene)
	_shown = move_toward(_shown, _goal, delta * 1.5)
	_bar_fill.size = Vector2(_bar_back.size.x * _shown, _bar_back.size.y)


func _built_from(scene: PackedScene) -> void:
	_goal = READ_SHARE
	_world = scene.instantiate() as World
	_world.stepwise = true
	_world.building.connect(_on_building)
	_world.built.connect(_on_built)
	# (nothing runs till it is all in: he would be falling about a half-built hill)
	get_tree().paused = true
	get_tree().root.add_child(_world)
	get_tree().root.move_child(_world, get_index())


func _on_building(done: float, what: String) -> void:
	_goal = lerpf(READ_SHARE, 1.0, done)
	if what != "":
		_what.text = what
	# (the bar keeps up with a long step, so it never looks stuck)
	_shown = maxf(_shown, _goal - 0.08)
	_bar_fill.size = Vector2(_bar_back.size.x * _shown, _bar_back.size.y)


func _on_built() -> void:
	_goal = 1.0
	_what.text = "Off you go!"
	await get_tree().create_timer(0.35).timeout
	get_tree().paused = false
	var fade := create_tween()
	fade.tween_property(get_child(0), ^"modulate:a", 0.0, 0.5)
	fade.tween_callback(queue_free)
