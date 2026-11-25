extends SceneTree

## Run by the export plugin with the pack of an exported project: loads every script in it,
## so that Godot reports the ones that do not compile. The export plugin reads the output.
##
## The autoloads are freed before they enter the tree and no scene is opened. What still runs
## of the project is what loading a script runs: static initializers, and _init() of the autoloads.

const CHECKED : String = "GDMaim - Scripts checked: "


func _initialize() -> void:
	for node in root.get_children():
		root.remove_child(node)
		node.free()

	print(CHECKED, _load_scripts("res://"))
	quit()


func _load_scripts(dir : String) -> int:
	var count : int = 0
	for file in DirAccess.get_files_at(dir):
		# A script exported as binary tokens is a .gdc file, which a .gd.remap leads to
		file = file.trim_suffix(".remap")
		if file.get_extension() == "gd":
			load(dir.path_join(file))
			count += 1
	for sub_dir in DirAccess.get_directories_at(dir):
		count += _load_scripts(dir.path_join(sub_dir))
	return count
