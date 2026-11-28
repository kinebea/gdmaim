extends Node

## Syntax of newer versions of Godot: a variadic function, a static variable with a setter, a typed
## constant array with a trailing comma, and StringName and NodePath literals given as arguments.

static var pn_level : int = 0:
	set(value):
		pn_level = maxi(value, 1)

const PN_STEPS : Array[int] = [1, 2, 3,]

func pn_sum(first : int, ...rest : Array) -> int:
	var total : int = first
	for value in rest:
		total += value
	return total

func pn_named(name_of : StringName, path : NodePath) -> String:
	return str(name_of) + "|" + str(path)

func run_case() -> String:
	if pn_sum(1) != 1 or pn_sum(1, 2, 3) != 6:
		return "variadic function: %d" % pn_sum(1, 2, 3)
	pn_level = -3
	if pn_level != 1:
		return "static variable with a setter: %d" % pn_level
	if PN_STEPS.size() != 3:
		return "typed constant array"
	if pn_named(&"pn_level", ^"a/b:c") != "pn_level|a/b:c":
		return "literals as arguments: " + pn_named(&"pn_level", ^"a/b:c")
	return "ok"
