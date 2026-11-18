extends RefCounted

## Of a line with a "method" key only the name of the method is replaced.

func run_case() -> String:
	var first : Node = load("res://cases/resources/data/method_key.tscn").instantiate()
	var action : Dictionary = first.action_zq
	var callable_name : bool = first.has_method(action.get("method", ""))
	first.free()
	if action.get("target") != "enemy" or !callable_name:
		return "key after the method key: " + str(action)

	var second : Node = load("res://cases/resources/data/method_key_last.tscn").instantiate()
	var last : Dictionary = second.action_last_zq
	var callable_last : bool = second.has_method(last.get("method", ""))
	second.free()
	if last.get("args") != [1] or !callable_last:
		return "method key as the last one: " + str(last)
	return "ok"
