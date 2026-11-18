extends SceneTree

## Checks the line mappings of the newest source map of the test project.
## Run by tests/run.sh from inside the project, after an export.
##
## Every string beginning with "mark:" in cases/tokenizer/source_lines.gd is looked up in the source
## and in the exported code. The mapping of its exported line has to lead to its source line.

const SCRIPT_PATH : String = "res://cases/tokenizer/source_lines.gd"

func _init() -> void:
	var result : String = check()
	print("[CASE] ", "PASS" if result == "ok" else "FAIL", " | source map/line mappings | ", result)
	print("[DONE]")
	quit()

func check() -> String:
	var dir : String = "res://addons/gdmaim/source_maps"
	var newest : String = ""
	for file in DirAccess.get_files_at(dir):
		if file.get_extension() == "map" and file > newest:
			newest = file
	if newest.is_empty():
		return "no source map was written"

	var bytes : PackedByteArray = FileAccess.get_file_as_bytes(dir + "/" + newest)
	var data = JSON.parse_string(bytes.slice(1).get_string_from_utf8())
	if !(data is Dictionary) or !data.get("scripts", {}).has(SCRIPT_PATH):
		return "the source map does not hold " + SCRIPT_PATH
	var script : Dictionary = data["scripts"][SCRIPT_PATH]
	var source : PackedStringArray = script["source_code"].split("\n")
	var exported : PackedStringArray = script["export_code"].split("\n")
	var mappings : Dictionary = script["export_mappings"]

	var wrong : PackedStringArray = []
	var marks : int = 0
	for source_line in source.size():
		var from : int = source[source_line].find("\"mark:")
		if from == -1 or source[source_line].strip_edges().begins_with("#"):
			continue
		marks += 1
		var mark : String = source[source_line].substr(from, source[source_line].find("\"", from + 1) - from + 1)
		var export_line : int = -1
		for line in exported.size():
			if exported[line].contains(mark):
				export_line = line
				break
		if export_line == -1:
			wrong.append(mark + " is not in the exported code")
			continue
		var mapped : int = int(mappings.get(str(export_line), -1))
		if mapped != source_line:
			wrong.append("%s is on line %d, its exported line %d leads to line %d" % [mark, source_line + 1, export_line + 1, mapped + 1])
	if marks == 0:
		return "no marks found in the source"
	return "ok" if wrong.is_empty() else "; ".join(wrong)
