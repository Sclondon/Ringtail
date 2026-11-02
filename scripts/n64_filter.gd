class_name N64Filter
extends CanvasLayer
## The N64 look over everything under the HUD (Liquid Metal's shader: about 300
## lines, 5-bit colour, dither, the soft upscale). Hide it to see the game plain.

static var lines := 300.0


func _ready() -> void:
	layer = 1
	var screen := ColorRect.new()
	screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var filter := ShaderMaterial.new()
	filter.shader = preload("res://shaders/n64.gdshader")
	filter.set_shader_parameter(&"lines", lines)
	screen.material = filter
	add_child(screen)
