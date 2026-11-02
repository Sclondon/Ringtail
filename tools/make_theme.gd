extends SceneTree
## Saves UiStyle's theme as res://ui/theme.tres (the project's theme: gui/theme/custom). Run after changing UiStyle:
##   godot --headless --path . --audio-driver Dummy -s res://tools/make_theme.gd


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://ui"))
	var error := ResourceSaver.save(UiStyle.build(), "res://ui/theme.tres")
	print("THEME saved" if error == OK else "THEME failed: %d" % error)
	quit()
