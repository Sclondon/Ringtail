class_name FishingButton
extends Control
## A round button drawn with a symbol (no words), and the key that does the same in small under it (from Gloaming's
## SymbolButton, GameCommon godot/fishing).
## Pressed and released by the mouse or a touch.

signal pressed
signal released

enum Symbol { CROSS, CAST, HOOK, REEL, PLAY }

var symbol := Symbol.CROSS
var key := ""
var down := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP


func _gui_input(event: InputEvent) -> void:
	var press := false
	var lift := false
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		press = event.pressed
		lift = not event.pressed
	elif event is InputEventScreenTouch:
		press = event.pressed
		lift = not event.pressed
	if press and not down:
		down = true
		pressed.emit()
		queue_redraw()
		accept_event()
	elif lift and down:
		down = false
		released.emit()
		queue_redraw()
		accept_event()


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT and down:
		down = false
		released.emit()
		queue_redraw()


func _draw() -> void:
	var r := size.x * 0.5
	var c := Vector2(r, r)
	draw_circle(c, r, Color(0.06, 0.05, 0.04, 0.8 if down else 0.62))
	draw_arc(c, r - 1.5, 0.0, TAU, 40, Color(0.95, 0.8, 0.45), 3.0, true)
	var ink := Color(1.0, 0.95, 0.85)
	var w := maxf(r * 0.1, 2.5)
	match symbol:
		Symbol.CROSS:
			var d := r * 0.38
			draw_line(c + Vector2(-d, -d), c + Vector2(d, d), ink, w, true)
			draw_line(c + Vector2(-d, d), c + Vector2(d, -d), ink, w, true)
		Symbol.CAST:
			# a rod swung over, the line flying out
			draw_line(c + Vector2(-r * 0.45, r * 0.45), c + Vector2(r * 0.2, -r * 0.4), ink, w, true)
			draw_arc(c + Vector2(r * 0.25, -r * 0.05), r * 0.4, -PI * 0.9, -PI * 0.1, 12, ink, w * 0.5, true)
			draw_circle(c + Vector2(r * 0.62, r * 0.15), r * 0.1, Color(0.9, 0.25, 0.2))
		Symbol.HOOK:
			draw_line(c + Vector2(0.0, -r * 0.5), c + Vector2(0.0, r * 0.15), ink, w, true)
			draw_arc(c + Vector2(-r * 0.2, r * 0.15), r * 0.2, 0.0, PI, 12, ink, w, true)
			draw_line(c + Vector2(-r * 0.4, r * 0.15), c + Vector2(-r * 0.3, -r * 0.02), ink, w, true)
		Symbol.REEL:
			draw_arc(c, r * 0.42, -PI * 0.2, PI * 1.5, 24, ink, w, true)
			var tip := c + Vector2.from_angle(-PI * 0.2) * r * 0.42
			draw_colored_polygon(PackedVector2Array([tip + Vector2(r * 0.18, -r * 0.05), tip + Vector2(-r * 0.12, -r * 0.2), tip + Vector2(-r * 0.05, r * 0.15)]), ink)
		Symbol.PLAY:
			draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.25, -r * 0.4), c + Vector2(r * 0.4, 0.0), c + Vector2(-r * 0.25, r * 0.4)]), ink)
	if key != "" and r > 8.0:
		draw_string(get_theme_default_font(), Vector2(0.0, size.y + r * 0.32), key, HORIZONTAL_ALIGNMENT_CENTER, size.x, int(r * 0.32), Color(1.0, 0.95, 0.85, 0.85))
