class_name UiStyle
extends RefCounted
## The game's look for every menu, button and counter (the user, 2026-11-02: "give the UI a pass, the basic shapes are
## ugly"): a Pacific Northwest wood, deep fir-green panels in a dark bark rim with a thick lower edge (pressed, it
## sinks), cream lettering in a bark outline, amber where something is picked or held. Built here and saved as the
## project's theme (res://ui/theme.tres, gui/theme/custom) by tools/make_theme.gd:
##   godot --headless --path . --audio-driver Dummy -s res://tools/make_theme.gd
## Variations: "Badge" (a PanelContainer: the HUD's counters, a pill), "Card" (a PanelContainer: the pause screen's
## middle), "Small" (a Button: the testing panel's).

const FIR := Color(0.13, 0.23, 0.17)
const FIR_LIGHT := Color(0.2, 0.33, 0.23)
const FIR_DEEP := Color(0.08, 0.15, 0.11)
const BARK := Color(0.1, 0.065, 0.045)
const WOOD := Color(0.45, 0.29, 0.16)
const CREAM := Color(0.99, 0.94, 0.81)
const MOSS := Color(0.58, 0.72, 0.32)
const AMBER := Color(0.96, 0.66, 0.26)
const EMBER := Color(0.72, 0.42, 0.16)

const FONT := preload("res://fonts/PixelifySans.ttf")


static func build() -> Theme:
	var theme := Theme.new()
	theme.default_font = FONT
	theme.default_font_size = 20
	# Buttons: a raised wooden-rimmed green tile, sinking when pressed; amber when picked (a tab, a held button)
	theme.set_stylebox(&"normal", &"Button", _tile(FIR, BARK, 7))
	theme.set_stylebox(&"hover", &"Button", _tile(FIR_LIGHT, BARK, 7))
	theme.set_stylebox(&"pressed", &"Button", _tile(EMBER, BARK, 3, 4))
	theme.set_stylebox(&"hover_pressed", &"Button", _tile(AMBER.darkened(0.15), BARK, 3, 4))
	theme.set_stylebox(&"disabled", &"Button", _tile(FIR_DEEP, BARK.lightened(0.1), 4))
	theme.set_stylebox(&"focus", &"Button", StyleBoxEmpty.new())
	for state: StringName in [&"font_color", &"font_hover_color", &"font_focus_color", &"font_hover_pressed_color"]:
		theme.set_color(state, &"Button", CREAM)
	theme.set_color(&"font_pressed_color", &"Button", Color(1.0, 0.97, 0.88))
	theme.set_color(&"font_disabled_color", &"Button", CREAM.darkened(0.45))
	theme.set_color(&"font_outline_color", &"Button", BARK)
	theme.set_constant(&"outline_size", &"Button", 5)
	# The small testing buttons
	theme.set_type_variation(&"Small", &"Button")
	theme.set_stylebox(&"normal", &"Small", _tile(FIR, BARK, 4, 0, 10, 0.85))
	theme.set_stylebox(&"hover", &"Small", _tile(FIR_LIGHT, BARK, 4, 0, 10, 0.9))
	theme.set_stylebox(&"pressed", &"Small", _tile(EMBER, BARK, 2, 2, 10))
	theme.set_font_size(&"font_size", &"Small", 15)
	# Panels: the fur editor's, the fishing panel's, anything boxed
	theme.set_stylebox(&"panel", &"PanelContainer", _panel(Color(FIR_DEEP, 0.94), BARK, 4, 22, 12))
	theme.set_stylebox(&"panel", &"Panel", _panel(Color(FIR_DEEP, 0.94), BARK, 4, 22, 12))
	theme.set_type_variation(&"Card", &"PanelContainer")
	var card := _panel(Color(FIR_DEEP, 0.96), BARK, 5, 30, 16)
	card.border_width_top = 5
	card.content_margin_left = 40
	card.content_margin_right = 40
	card.content_margin_top = 28
	card.content_margin_bottom = 34
	theme.set_stylebox(&"panel", &"Card", card)
	# Counters: a dark pill in a wooden rim
	theme.set_type_variation(&"Badge", &"PanelContainer")
	var badge := _panel(Color(BARK, 0.62), WOOD, 3, 40, 4)
	badge.content_margin_left = 10
	badge.content_margin_right = 18
	badge.content_margin_top = 4
	badge.content_margin_bottom = 4
	theme.set_stylebox(&"panel", &"Badge", badge)
	# Lettering: cream in a bark outline
	theme.set_color(&"font_color", &"Label", CREAM)
	theme.set_color(&"font_outline_color", &"Label", BARK)
	theme.set_constant(&"outline_size", &"Label", 6)
	# The dial (HSlider): a sunk groove, amber up to a round cream knob
	var groove := _panel(BARK, BARK, 0, 8, 0)
	groove.content_margin_top = 7
	groove.content_margin_bottom = 7
	theme.set_stylebox(&"slider", &"HSlider", groove)
	var filled := _panel(AMBER, BARK, 2, 8, 0)
	filled.content_margin_top = 7
	filled.content_margin_bottom = 7
	theme.set_stylebox(&"grabber_area", &"HSlider", filled)
	theme.set_stylebox(&"grabber_area_highlight", &"HSlider", filled)
	theme.set_icon(&"grabber", &"HSlider", _knob(30, CREAM))
	theme.set_icon(&"grabber_highlight", &"HSlider", _knob(30, Color(1.0, 0.86, 0.6)))
	theme.set_icon(&"grabber_disabled", &"HSlider", _knob(30, CREAM.darkened(0.4)))
	# Tooltips
	theme.set_stylebox(&"panel", &"TooltipPanel", _panel(Color(BARK, 0.95), WOOD, 2, 10, 4))
	theme.set_color(&"font_color", &"TooltipLabel", CREAM)
	theme.set_font_size(&"font_size", &"TooltipLabel", 16)
	# Scroll bars (the fur editor's list): thin, rounded
	var bar := _panel(Color(BARK, 0.5), BARK, 0, 6, 0)
	bar.content_margin_left = 5
	bar.content_margin_right = 5
	theme.set_stylebox(&"scroll", &"VScrollBar", bar)
	var thumb := _panel(MOSS, BARK, 2, 6, 0)
	thumb.content_margin_left = 5
	thumb.content_margin_right = 5
	theme.set_stylebox(&"grabber", &"VScrollBar", thumb)
	theme.set_stylebox(&"grabber_highlight", &"VScrollBar", _panel(MOSS.lightened(0.2), BARK, 2, 6, 0))
	theme.set_stylebox(&"grabber_pressed", &"VScrollBar", _panel(AMBER, BARK, 2, 6, 0))
	return theme


## A button's tile: `face` in a `rim`, its lower edge `lip` thick (the tile's depth), `sink` pushed down when pressed.
static func _tile(face: Color, rim: Color, lip: int, sink := 0, round := 18, alpha := 0.94) -> StyleBoxFlat:
	var tile := StyleBoxFlat.new()
	tile.bg_color = Color(face, alpha)
	tile.border_color = rim
	tile.set_border_width_all(3)
	tile.border_width_bottom = lip
	tile.set_corner_radius_all(round)
	tile.corner_detail = 6
	tile.shadow_color = Color(0.0, 0.0, 0.0, 0.32)
	tile.shadow_size = 3 if sink == 0 else 1
	tile.shadow_offset = Vector2(0, 3 if sink == 0 else 1)
	tile.expand_margin_top = -sink
	tile.content_margin_left = 14
	tile.content_margin_right = 14
	tile.content_margin_top = 6 + sink
	tile.content_margin_bottom = 6
	tile.anti_aliasing = true
	return tile


static func _panel(face: Color, rim: Color, width: int, round: int, shadow: int) -> StyleBoxFlat:
	var panel := StyleBoxFlat.new()
	panel.bg_color = face
	panel.border_color = rim
	panel.set_border_width_all(width)
	panel.set_corner_radius_all(round)
	panel.corner_detail = 8
	panel.shadow_color = Color(0.0, 0.0, 0.0, 0.35)
	panel.shadow_size = shadow
	panel.shadow_offset = Vector2(0, shadow * 0.4)
	panel.content_margin_left = 18
	panel.content_margin_right = 18
	panel.content_margin_top = 14
	panel.content_margin_bottom = 14
	return panel


## The dial's knob: a round `face` in a bark rim, a little shine on top.
static func _knob(size: int, face: Color) -> ImageTexture:
	var image := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	var middle := Vector2(size, size) * 0.5
	var r := size * 0.5 - 1.0
	for y in size:
		for x in size:
			var p := Vector2(x + 0.5, y + 0.5)
			var d := p.distance_to(middle)
			var colour := Color(0, 0, 0, 0)
			if d < r:
				colour = BARK
			if d < r - 3.0:
				colour = face
				if p.distance_to(middle + Vector2(-r * 0.25, -r * 0.3)) < r * 0.28:
					colour = face.lightened(0.5)
			colour.a *= clampf(r - d + 0.5, 0.0, 1.0)
			image.set_pixel(x, y, colour)
	return ImageTexture.create_from_image(image)
