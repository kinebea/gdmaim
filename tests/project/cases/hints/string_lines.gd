extends RefCounted

## ##OBFUSCATE_STRINGS applies to the strings of the source line it is written on,
## also where that line ends up on one output line with others.

var sl_speed : int = 5

func run_case() -> String:
	var names : Array = [
		"res://data/table.csv",
		"sl_speed", ##OBFUSCATE_STRINGS
	]
	var entry : Dictionary = {
		"icon": "res://data/table.csv",
		"sl_speed": 1, ##OBFUSCATE_STRINGS
	}
	if get(names[1]) != 5:
		return "the hinted string does not name the variable: " + names[1]
	if names[0] != "res://data/table.csv":
		return "a string on another line of the array changed: " + names[0]
	if !entry.has("icon") or entry["icon"] != "res://data/table.csv":
		return "a string on another line of the dictionary changed: " + str(entry)
	return "ok"
