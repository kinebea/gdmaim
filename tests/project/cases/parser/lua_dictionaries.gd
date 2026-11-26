extends RefCounted

## The keys of `{ key = value }` are strings and stay as they are, whatever else has that name.

var ld_health : int = 10
var ld_name : String = "bob"

func as_dictionary() -> Dictionary:
	return {ld_health = ld_health, ld_name = ld_name}

func from_parameter(ld_power) -> Dictionary:
	return {ld_power = ld_power}

func from_local() -> Dictionary:
	var ld_local : int = 4
	return {ld_local = ld_local}

static func from_locals_over_lines(raw : Dictionary) -> Dictionary:
	var ld_stats : Array = raw.get("ld_stats")
	var ld_items : Array = raw.get("ld_items")
	return {
		ID = raw.ID,
		ld_stats = ld_stats.map(func(x: Dictionary) -> Dictionary: return {type = x.type, level = float(x.level)}),
		ld_items = ld_items.map(func(x: Dictionary) -> Dictionary: return {GUID = x.GUID}),
	}

func run_case() -> String:
	var local : Dictionary = from_local()
	if !local.has("ld_local") or local["ld_local"] != 4:
		return "key named like a local variable: " + str(local.keys())
	var over_lines : Dictionary = from_locals_over_lines({ID = 1, ld_stats = [{type = "hp", level = 2}], ld_items = [{GUID = "g"}]})
	if !over_lines.has("ld_stats") or !over_lines.has("ld_items") or over_lines.ld_stats[0].level != 2.0:
		return "keys named like local variables, over several lines: " + str(over_lines.keys())
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
