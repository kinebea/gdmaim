extends SceneTree

## Translates the log of a game exported with GDMaim back to the source code: the generated names
## to the names of the source, the lines of the exported scripts to the lines of the source.
## To be run from the project the game was exported from:
##
##   godot --headless --path . -s res://addons/gdmaim/util/translate_log.gd -- <log> [--map=<source map>] [--out=<file>]
##
## Without --map, the source map is the one the log names, looked for in the 'Output Path' of the
## source maps. Without --out, the translated log is printed.

const USAGE : String = "Usage: godot --headless --path <project> -s res://addons/gdmaim/util/translate_log.gd -- <log> [--map=<source map>] [--out=<file>]"

const _LogTranslator := preload("log_translator.gd")
const _Settings := preload("../settings.gd")


func _initialize() -> void:
	# Nothing of the project has to run for this
	for node in root.get_children():
		root.remove_child(node)
		node.free()

	quit(_run(OS.get_cmdline_user_args()))


func _run(args : PackedStringArray) -> int:
	var log_path : String
	var map_path : String
	var out_path : String
	for arg in args:
		if arg.begins_with("--map="):
			map_path = arg.trim_prefix("--map=")
		elif arg.begins_with("--out="):
			out_path = arg.trim_prefix("--out=")
		elif log_path.is_empty() and !arg.begins_with("--"):
			log_path = arg
		else:
			return _fail("Unknown argument '" + arg + "'\n" + USAGE)
	if log_path.is_empty():
		return _fail(USAGE)
	if !FileAccess.file_exists(log_path):
		return _fail("There is no log at '" + log_path + "'")
	var text : String = FileAccess.get_file_as_string(log_path)

	if map_path.is_empty():
		var map_name : String = _LogTranslator.find_source_map_name(text)
		if map_name.is_empty():
			return _fail("The log does not name its source map, which takes the setting 'Inject Name'. Name the source map of that export with --map=<source map>")
		map_path = _Settings.new(false).source_map_path.path_join(map_name)
		if !FileAccess.file_exists(map_path):
			return _fail("The source map of the log is not at '" + map_path + "'. Name where it is with --map=<source map>")
	var source_map : Dictionary = _LogTranslator.load_source_map(map_path)
	if source_map.is_empty():
		return _fail("'" + map_path + "' is not a source map")

	var translated : String = _LogTranslator.translate(text, source_map)
	if out_path.is_empty():
		print(translated)
		return 0
	var file := FileAccess.open(out_path, FileAccess.WRITE)
	if !file:
		return _fail("Failed to write to '" + out_path + "'")
	file.store_string(translated)
	file.close()
	print("GDMaim - The log has been translated with '" + map_path + "' and saved to '" + out_path + "'")
	return 0


func _fail(message : String) -> int:
	printerr("GDMaim - " + message)
	return 1
