class_name YardDog
extends Dog
## A yard dog: GameCommon's Dog (its every move) on YardDogRig, one of Ringtail's friendly breeds (the user,
## 2026-11-02: "the dog needs to look less hellish", "should be like a shiba inu and beagle and blood hound and
## basset hound and wiener dog").

## Which dog: shiba, beagle, bloodhound, basset, dachshund.
var breed := "shiba"


func _ready() -> void:
	var made := YardDogRig.new()
	made.breed = breed
	made.name = "Rig"
	made.variant = variant
	made.low_poly = low_poly
	made.fur_shells = 0
	made.coat_tint = coat_tint
	made.mange = 0.0
	made.eyeshine = 0.0
	rig = made
	add_child(rig)
