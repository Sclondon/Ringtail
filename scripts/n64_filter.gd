class_name N64Filter
extends CanvasLayer
## The retro look over everything under the HUD: Close Encounters' (the user, 2026-11-02: "the pixel filter should
## be more like close encounters"): the world in hard pixels, 15-bit colour with the PlayStation's 4x4 dither, darker
## at the corners (shaders/ps1_screen.gdshader). How strong is the pause screen's Pixels dial ("it should be in the
## pause screen with a dial"): `strength` 0 is off, 1 the chunkiest; kept in user://settings.cfg.

const SETTINGS := "user://settings.cfg"
## The picture's height in lines at the dial's two ends (Close Encounters draws 300).
const FEWEST := 160.0
const MOST := 720.0

static var strength := 0.75
static var _current: N64Filter

var _filter: ShaderMaterial


func _ready() -> void:
	layer = 1
	_current = self
	var screen := ColorRect.new()
	screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_filter = ShaderMaterial.new()
	_filter.shader = preload("res://shaders/ps1_screen.gdshader")
	screen.material = _filter
	add_child(screen)
	var saved := ConfigFile.new()
	if saved.load(SETTINGS) == OK:
		strength = float(saved.get_value("look", "pixels", strength))
	_apply()


## Sets the dial (0 off .. 1 chunkiest), now and for next time.
static func set_strength(to: float) -> void:
	strength = clampf(to, 0.0, 1.0)
	var saved := ConfigFile.new()
	saved.load(SETTINGS)
	saved.set_value("look", "pixels", strength)
	saved.save(SETTINGS)
	if is_instance_valid(_current):
		_current._apply()


func _apply() -> void:
	visible = strength > 0.02
	_filter.set_shader_parameter(&"lines", lerpf(MOST, FEWEST, strength))
	_filter.set_shader_parameter(&"dither", strength > 0.15)
