extends RefCounted

## `var name` in a match pattern binds a value. The colon after it begins the branch.

func suffix() -> String:
	return "!"

func bound(value) -> String:
	match value:
		1:
			return "one"
		var mp_other:
			return str(mp_other, suffix())

func in_array(command) -> String:
	match command:
		["move", var mp_direction]:
			return "m" + str(mp_direction)
		["look", var mp_target]:
			return "l" + str(mp_target)
		{"name": var mp_name, ..}:
			return "n" + str(mp_name)
	return ""

func guarded(value) -> String:
	match value:
		var mp_number when mp_number < 0:
			return "negative"
		var mp_large when mp_large > 100:
			return "big"
	return "medium"

func run_case() -> String:
	if bound(1) != "one" or bound(7) != "7!":
		return "binding: " + bound(7)
	if in_array(["move", 1]) != "m1" or in_array(["look", 2]) != "l2" or in_array({"name": "x", "age": 1}) != "nx":
		return "binding inside an array or a dictionary"
	if guarded(-1) != "negative" or guarded(500) != "big" or guarded(5) != "medium":
		return "binding with a guard"
	return "ok"
