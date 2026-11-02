class_name Chatter
extends CanvasLayer
## The other raccoons talk as the crows in Hemlock's Tower do (the user, 2026-11-02: "the text should just be like
## Hemlock's Tower where they say things rather than like a popup"): come near one with something to say and it
## turns to him and says it in a speech bubble over its head (SpeechBubble, from Hemlock's Tower), then its next
## line a little after, and so on while he stays; walk off and it goes back to what it was doing. Nothing to press,
## and he is never stopped.
##
## Anyone to talk is in `Villagers.members` with `lines` (Villager.talks()).

## How near he must come, how long each line shows and the pause before the next.
const REACH := 2.6
const SHOWN := 3.6
const PAUSE := 1.2

var villagers: Villagers
var _overlay: Control
var _bubbles := {}
var _line := {}
var _wait := {}
var _near := {}


func _ready() -> void:
	layer = 3
	_overlay = Control.new()
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_overlay)
	SpeechBubble.overlay = _overlay
	SpeechBubble.view_scale = 1.0


## The bubble over `who`'s head (made the first time it is wanted).
func bubble_of(who: Villager) -> SpeechBubble:
	if not _bubbles.has(who):
		var bubble := SpeechBubble.new()
		bubble.position.y = 0.6 if who.kit else 0.95
		who.add_child(bubble)
		_bubbles[who] = bubble
		_line[who] = 0
		_wait[who] = 0.0
	return _bubbles[who]


func _process(delta: float) -> void:
	var hero := villagers.player
	if hero == null:
		return
	for who: Villager in villagers.members:
		if not is_instance_valid(who) or not who.talks():
			continue
		var near := not who.dead and who.doing != Villager.Doing.FLEE \
				and hero.global_position.distance_to(who.global_position) < REACH
		var was: bool = _near.get(who, false)
		if not near and not was and not _bubbles.has(who):
			continue
		var bubble := bubble_of(who)
		if near and not was:
			who.listen(true)
			_wait[who] = 0.0
		elif was and not near:
			who.listen(false)
		_near[who] = near
		if near:
			_wait[who] = float(_wait[who]) - delta
			if _wait[who] <= 0.0:
				# (its next line; round again after the last)
				var k: int = _line[who]
				bubble.say(who.lines[k % who.lines.size()], SHOWN)
				_line[who] = k + 1
				_wait[who] = SHOWN + PAUSE
		bubble.tick(delta, false)
		if not near:
			bubble.hold = 0.0
