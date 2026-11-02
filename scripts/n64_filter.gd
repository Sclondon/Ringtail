class_name N64Filter
extends CanvasLayer
## The N64 look over everything under the HUD (Liquid Metal's shader, softened: about 520
## lines, 6-bit colour, a light dither, the soft upscale). Hide it to see the game plain.

static var lines := 520.0


func _ready() -> void:
	layer = 1
	var screen := ColorRect.new()
	screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var filter := ShaderMaterial.new()
	filter.shader = preload("res://shaders/n64.gdshader")
	filter.set_shader_parameter(&"lines", lines)
	# (softened from Liquid Metal's 5 bits and 0.4: the user found it too strong, 2026-11-01)
	filter.set_shader_parameter(&"levels", 63.0)
	filter.set_shader_parameter(&"dither", 0.25)
	screen.material = filter
	add_child(screen)
