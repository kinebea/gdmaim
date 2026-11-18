extends RefCounted

## A path to a property keeps the colon it begins with.

func run_case() -> String:
	var actor : Node = load("res://cases/resources/data/property_path.tscn").instantiate()
	var path : String = str(actor.path_zq)
	actor.free()
	if path != ":position":
		return "path to a property: " + path
	return "ok"
