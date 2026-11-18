extends RefCounted

## Scripts saved inside a scene or a resource are obfuscated like any other.
## One holds escaped quotes and backslashes, one does not end with a line break,
## and one is that of a .tres file.

func call_on(node : Node, method : Callable) -> String:
	var script = node.get_script()
	if script == null or !script.can_instantiate():
		return "does not compile"
	return str(method.call())

func run_case() -> String:
	var quoted : Node = load("res://cases/resources/data/builtin_quotes.tscn").instantiate()
	var text : String = call_on(quoted, func(): return quoted.get_text_zq())
	quoted.free()
	if text != "\"7\"":
		return "script with escaped quotes: " + text

	var no_newline : Node = load("res://cases/resources/data/builtin_no_newline.tscn").instantiate()
	var ping : String = call_on(no_newline, func(): return no_newline.ping_zq())
	no_newline.free()
	if ping != "7":
		return "script without a line break at its end: " + ping

	var resource : Resource = load("res://cases/resources/data/builtin_resource.tres")
	var script = resource.get_script()
	if script == null or !script.can_instantiate():
		return "script of a .tres file does not compile"
	if resource.total_zq() != 42:
		return "script of a .tres file: %s" % resource.total_zq()
	return "ok"
