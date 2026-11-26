extends Node

## A function that reads the names of members from get_script_method_list() or the like, and picks
## some of them by a part of their name, no longer finds those that get renamed. GDMaim warns about it
## when it exports, which the configurations look for in the output of the export, unless what it
## picks keeps its name. The function that would not find them is never called.

static func np_read_first() -> int:
	return 1

static func np_locked_first() -> int: ##LOCK_SYMBOLS
	return 2

func np_not_run() -> int:
	var found : int = 0
	for method in get_script().get_script_method_list():
		var name : String = method["name"]
		if name.begins_with("np_read_"):
			found += 1
		if name.ends_with("_first"):
			found += 1
		# Not warned about: what only a locked method has, or nothing has
		if name.begins_with("np_locked_") or name.begins_with("res://"):
			found += 1
	return found

# Not warned about: a function that does not read the names of members
func np_elsewhere(text : String) -> bool:
	return text.begins_with("np_read_")

func run_case() -> String:
	return "ok"
