extends SceneTree

## Checks the tab "Log" of the source map viewer with the newest source map of the test project.
## Run by tests/run.sh from inside the project, with the log of a game that ran with the feature
## tag `crash` as its argument.
##
## The log, entered in the tab, has to come out translated. Putting the caret on a line of the
## translation that names a script has to open that script on that line.

const VIEWER : String = "res://addons/gdmaim/ui/source_map_viewer/source_map_viewer.tscn"
const TRANSLATED : String = "at: Engine_part.heat_up (res://broken/at_runtime.gd:14)"

var _started : bool = false

func _process(_delta : float) -> bool:
	if !_started:
		_started = true
		_run()
	return false

func _run() -> void:
	var result : String = await check()
	print("[CASE] ", "PASS" if result == "ok" else "FAIL", " | source map viewer/log | ", result)
	print("[DONE]")
	quit()

func check() -> String:
	var args : PackedStringArray = OS.get_cmdline_user_args()
	if args.is_empty() or !FileAccess.file_exists(args[0]):
		return "no log to enter"
	var dir : String = "res://addons/gdmaim/source_maps"
	var newest : String = ""
	for file in DirAccess.get_files_at(dir):
		if file.get_extension() == "map" and file > newest:
			newest = file
	if newest.is_empty():
		return "no source map was written"

	var viewer : Window = load(VIEWER).instantiate()
	root.add_child(viewer)
	var input : TextEdit = viewer.get_node_or_null("%LogInput")
	var translated : TextEdit = viewer.get_node_or_null("%LogTranslated")
	if !input or !translated:
		return "the viewer has no tab for a log"

	# A log entered ahead of the source map is translated once there is one
	input.text = FileAccess.get_file_as_string(args[0])
	input.text_changed.emit()
	if translated.text.contains("heat_up"):
		return "translated without a source map"
	viewer._load_source_map(dir + "/" + newest)
	if !translated.text.contains(TRANSLATED):
		return "the log is not translated once a source map is open"

	# And one entered after it right away
	input.text = ""
	input.text_changed.emit()
	if !translated.text.is_empty():
		return "the translation stays when the log is cleared"
	input.text = FileAccess.get_file_as_string(args[0])
	input.text_changed.emit()
	if !translated.text.contains(TRANSLATED):
		return "the log is not translated when it is entered"

	for line in translated.get_line_count():
		if translated.get_line(line).contains(TRANSLATED):
			translated.set_caret_line(line)
			break
	await process_frame
	await process_frame
	if viewer._script_data.get("path", "") != "res://broken/at_runtime.gd":
		return "the script a line names is not opened, but '%s'" % viewer._script_data.get("path", "")
	var source_line : String = viewer.source_code.get_line(viewer.source_code.get_caret_line())
	if !source_line.contains("missing_sensor.read_temperature"):
		return "the caret is not on the line that failed, but on: " + source_line.strip_edges()
	return "ok"
