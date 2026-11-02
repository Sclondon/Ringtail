class_name YardDogRig
extends DogRig
## A yard dog's rig: GameCommon's DogRig on one of Ringtail's own friendly dogs (tools/build_yard_dog.py:
## models/yard_dog_<breed>.glb, the same bones), shaded as the raccoon is (Toon) in the coat colours painted into
## its vertex colours; its eyes, nose, mouth and teeth as the dog component draws them, with no eyeshine.

## Which dog: shiba, beagle, bloodhound, basset, dachshund.
var breed := "shiba"


func _model_path() -> String:
	return "res://models/yard_dog_%s%s.glb" % [breed, "_lo" if low_poly else ""]


func _dress(model: Node) -> Dictionary:
	# (the component's dress for the eyes, nose and mouth; then the coat made a toon one, coloured by its vertices)
	var made := DogLook.dress(model, Color.WHITE, 0, 0.0, 0.0)
	var shader := Shader.new()
	shader.code = Toon.SHADER.replace("ALBEDO = albedo * (1.0 - stripe * line);", "ALBEDO = albedo * COLOR.rgb;")
	var coat := ShaderMaterial.new()
	coat.shader = shader
	coat.set_shader_parameter(&"albedo", Color.WHITE)
	for part: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		for surface in part.mesh.get_surface_count():
			var original := part.mesh.surface_get_material(surface)
			if original and original.resource_name == "coat":
				part.set_surface_override_material(surface, coat)
	made["coat"] = coat
	return made
