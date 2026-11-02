class_name ScurryBars
extends CanvasLayer
## Black bars that slide in from the top and bottom of the screen while scurry is held, and out again when it is let
## go (the user, 2026-11-02: "black bars should come down from the top and bottom in scurry mode"). Under the HUD.
## Made by Scurry.

## How much of the screen's height each bar takes, fully in, and how quickly they come and go.
const SHARE := 0.1
const RATE := 5.0

var scurry: Scurry
var _top: ColorRect
var _bottom: ColorRect
var _in := 0.0


func _ready() -> void:
	layer = 2
	for k in 2:
		var bar := ColorRect.new()
		bar.color = Color.BLACK
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(bar)
		if k == 0:
			_top = bar
		else:
			_bottom = bar


func _process(delta: float) -> void:
	_in = move_toward(_in, 1.0 if scurry.held else 0.0, delta * RATE)
	var size := get_viewport().get_visible_rect().size
	var high := size.y * SHARE * smoothstep(0.0, 1.0, _in)
	_top.visible = high > 0.5
	_bottom.visible = _top.visible
	_top.position = Vector2.ZERO
	_top.size = Vector2(size.x, high)
	_bottom.position = Vector2(0.0, size.y - high)
	_bottom.size = Vector2(size.x, high)
