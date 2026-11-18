extends RefCounted

## The keys of `{ key = value }` are strings and stay as they are, whatever else has that name.

var ld_health : int = 10
var ld_name : String = "bob"

func as_dictionary() -> Dictionary:
	return {ld_health = ld_health, ld_name = ld_name}

func from_parameter(ld_power) -> Dictionary:
	return {ld_power = ld_power}

func run_case() -> String:
	var own : Dictionary = as_dictionary()
	if !own.has("ld_health") or own["ld_health"] != 10 or own.get("ld_name") != "bob":
		return "keys named like members: " + str(own.keys())
	var made : Dictionary = from_parameter(3)
	if !made.has("ld_power") or made["ld_power"] != 3:
		return "key named like a parameter: " + str(made.keys())
	var other : Dictionary = {boot_counter = 5, ld_unused_name = 6}
	if !other.has("boot_counter") or !other.has("ld_unused_name"):
		return "key named like a member of another script: " + str(other.keys())
	return "ok"
