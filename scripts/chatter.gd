class_name Chatter
extends CanvasLayer
## The other raccoons talk as the crows in Hemlock's Tower do (the user, 2026-11-02: "the text should just be like
## Hemlock's Tower where they say things rather than like a popup"): come near one with something to say and it
## turns to him and says it in a speech bubble over its head (SpeechBubble, from Hemlock's Tower), then its next
## line after a good pause: up to `PER_VISIT` lines a visit, going on from where it left off the time before (the user,
## 2026-11-02, "the raccoons need more things to say"); walk off and it goes back to what it was doing. Only the
## nearest one talks, one bubble at a time (the user, 2026-11-02: "they are spamming, why too many things"). Nothing
## to press, and he is never stopped.
##
## Anyone to talk is in `Villagers.members` with `lines` (Villager.talks()).

## How near he must come, how long each line shows and the pause before the next.
const REACH := 2.6
const SHOWN := 4.0
const PAUSE := 3.5
## How many lines one says each time he comes by.
const PER_VISIT := 3

var villagers: Villagers
var _overlay: Control
var _bubbles := {}
var _line := {}
var _wait := {}
var _near := {}
## How many it has said this visit.
var _said := {}


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
		# (over its head, however big it is)
		bubble.position.y = (0.6 / 0.5 if who.kit else 0.95) * float(who.build.get("size", 1.0))
		who.add_child(bubble)
		_bubbles[who] = bubble
		_line[who] = 0
		_wait[who] = 0.0
	return _bubbles[who]


## Whether one of them is talking to him now (then chats between the others do not show).
func busy() -> bool:
	for who in _near:
		if _near[who]:
			return true
	return false


func _process(delta: float) -> void:
	var hero := villagers.player
	if hero == null:
		return
	# (the one nearest him, of those that can talk, is the only one that talks)
	var nearest: Villager
	var best := REACH
	for who: Villager in villagers.members:
		if is_instance_valid(who) and who.talks() and not who.dead and who.doing != Villager.Doing.FLEE \
				and who.doing != Villager.Doing.CHAT and who.doing != Villager.Doing.CLIMB:
			var d := hero.global_position.distance_to(who.global_position)
			if d < best:
				best = d
				nearest = who
	for who: Villager in villagers.members:
		if not is_instance_valid(who):
			continue
		# (chatting with another: its bubble is the chat's, Villagers._turns; kept up here, not cut short)
		if who.doing == Villager.Doing.CHAT:
			if _bubbles.has(who):
				_bubbles[who].tick(delta, false)
			_near[who] = false
			continue
		if not who.talks():
			continue
		var near := who == nearest
		var was: bool = _near.get(who, false)
		if not near and not was and not _bubbles.has(who):
			continue
		var bubble := bubble_of(who)
		if near and not was:
			who.listen(true)
			_wait[who] = 0.0
			_said[who] = 0
		elif was and not near:
			who.listen(false)
		_near[who] = near
		if near:
			_wait[who] = float(_wait[who]) - delta
			if _wait[who] <= 0.0 and int(_said.get(who, 0)) < mini(PER_VISIT, who.lines.size()):
				# (its next line, round again after the last)
				var k: int = _line[who]
				bubble.say(who.lines[k % who.lines.size()], SHOWN, who.display_name)
				_line[who] = k + 1
				_said[who] = int(_said.get(who, 0)) + 1
				_wait[who] = SHOWN + PAUSE
		bubble.tick(delta, false)
		if not near:
			bubble.hold = 0.0
