extends RefCounted

## Leads what a game exported with GDMaim has printed back to the source code, with the source map
## of its export: the generated names to the names of the source, and the lines of the exported
## scripts to the lines of the source.

const SOURCE_MAP_NOTE : String = "GDMaim - Source map '"


## The file name of the source map a log names, which the game prints when it starts if
## 'Inject Name' was on. Empty if the log names none
static func find_source_map_name(text : String) -> String:
	var from : int = text.find(SOURCE_MAP_NOTE)
	if from == -1:
		return ""
	from += SOURCE_MAP_NOTE.length()
	var to : int = text.find("'", from)
	return text.substr(from, to - from) if to != -1 else ""


## The source map a file holds, or an empty Dictionary if it holds none
static func load_source_map(path : String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if !file or file.get_length() < 2:
		return {}

	var json : String
	var compression : int = file.get_8()
	if compression == 255:
		json = file.get_buffer(file.get_length() - file.get_position()).get_string_from_utf8()
	elif compression <= FileAccess.COMPRESSION_BROTLI and file.get_length() > 9:
		var size : int = file.get_64()
		json = file.get_buffer(file.get_length() - file.get_position()).decompress(size, compression).get_string_from_utf8()

	var source_map = JSON.parse_string(json) if json.strip_edges().begins_with("{") else null
	return source_map if source_map is Dictionary else {}


## The text with the lines and the names of the source in place of the exported ones.
## What the source map does not know stays as it is
static func translate(text : String, source_map : Dictionary) -> String:
	var scripts : Dictionary = source_map.get("scripts", {})
	var names : Dictionary = source_map.get("symbols", {}).get("export", {})

	# The lines, as in "res://player.gd:12". They count from zero in the mappings
	var where := RegEx.create_from_string("(res://[^\\n:]+?\\.gd):(\\d+)")
	var parts : PackedStringArray = []
	var at : int = 0
	for found in where.search_all(text):
		var mappings : Dictionary = scripts.get(found.get_string(1), {}).get("export_mappings", {})
		var line : int = int(mappings.get(str(found.get_string(2).to_int() - 1), -1))
		if line == -1:
			continue
		parts.append(text.substr(at, found.get_start(2) - at))
		parts.append(str(line + 1))
		at = found.get_end(2)
	parts.append(text.substr(at))
	text = "".join(parts)

	# The names, wherever one stands as a word of its own
	var word := RegEx.create_from_string("[\\p{L}\\p{N}_]+")
	parts = []
	at = 0
	for found in word.search_all(text):
		var source_name = names.get(found.get_string())
		if !(source_name is String) or source_name == found.get_string():
			continue
		parts.append(text.substr(at, found.get_start() - at))
		parts.append(source_name)
		at = found.get_end()
	parts.append(text.substr(at))
	return "".join(parts)
