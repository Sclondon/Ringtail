extends SceneTree
## Triangle counts of the animals' models (the user, 2026-11-02: "decently low poly twilight princess esque level of
## detail" / "to improve performance"). Headless:
##   godot --headless --path . --audio-driver Dummy -s res://tests/tri_count.gd [-- names...]

const ANIMALS := ["cat", "cat_lo", "cat_sleek", "cat_shaggy", "cat_soft", "fox", "skunk", "badger", "rabbit",
	"beaver", "rat", "mouse", "weasel", "marten", "otter", "gopher", "prairie_dog", "opossum", "squirrel",
	"porcupine", "chipmunk", "ringtail", "frog", "turtle", "snake", "snake_rock", "burrow", "crow", "owl", "hawk",
	"yard_dog_shiba", "yard_dog_beagle", "yard_dog_bloodhound", "yard_dog_basset", "yard_dog_dachshund"]


func _initialize() -> void:
	var names: Array = Array(OS.get_cmdline_user_args())
	if names.is_empty():
		names = ANIMALS
	for name: String in names:
		var line := name.rpad(22)
		for suffix: String in ["", "_lo"]:
			if suffix != "" and name.ends_with("_lo"):
				continue
			var path := "res://models/%s%s.glb" % [name, suffix]
			if not ResourceLoader.exists(path):
				line += "%10s" % "-"
				continue
			var node: Node = (load(path) as PackedScene).instantiate()
			line += "%10d" % _tris(node)
			node.free()
		print(line)
	quit()


func _tris(node: Node) -> int:
	var total := 0
	if node is MeshInstance3D and (node as MeshInstance3D).mesh:
		var mesh: Mesh = (node as MeshInstance3D).mesh
		for s in mesh.get_surface_count():
			var arrays := mesh.surface_get_arrays(s)
			var index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			total += (index.size() if index.size() > 0 else (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()) / 3
	for child in node.get_children():
		total += _tris(child)
	return total
