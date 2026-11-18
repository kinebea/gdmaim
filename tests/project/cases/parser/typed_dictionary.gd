extends RefCounted

## `Dictionary[K, V]` is a dictionary like `Dictionary`: keys read through a dot are not renamed.

var td_health : int = 1
var td_plain : Dictionary = { "td_health": 5 }
var td_typed : Dictionary[String, int] = { "td_health": 10 }

func total(td_values : Dictionary[String, int]) -> int:
	return td_values.td_health + td_health

func run_case() -> String:
	if td_plain.td_health != 5:
		return "plain"
	if td_typed.td_health != 10:
		return "typed member"
	if total(td_typed) != 11:
		return "typed parameter"
	return "ok"
