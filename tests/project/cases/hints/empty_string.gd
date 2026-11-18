extends RefCounted

## An empty string stays empty when the strings of its line are obfuscated.

var es_damage : int = 3
var es_parts : Array = ["", "es_damage"] ##OBFUSCATE_STRINGS

func run_case() -> String:
	if es_parts[0] != "":
		return "the empty string became '%s'" % es_parts[0]
	if get(es_parts[1]) != 3:
		return "the other string does not name the variable"
	return "ok"
