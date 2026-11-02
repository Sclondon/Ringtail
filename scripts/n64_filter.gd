class_name N64Filter
extends CanvasLayer
## The retro look over everything under the HUD: Close Encounters' (the user, 2026-11-02: "the pixel filter should
## be more like close encounters"): the world at about 300 lines in hard pixels, 15-bit colour with the PlayStation's
## 4x4 dither, darker at the corners (shaders/ps1_screen.gdshader). It was Liquid Metal's N64 filter, softened (520
## lines, 6-bit colour, a smeared upscale). Hide it to see the game plain.

static var lines := 300.0


func _ready() -> void:
	layer = 1
	var screen := ColorRect.new()
	screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var filter := ShaderMaterial.new()
	filter.shader = preload("res://shaders/ps1_screen.gdshader")
	filter.set_shader_parameter(&"lines", lines)
	screen.material = filter
	add_child(screen)
