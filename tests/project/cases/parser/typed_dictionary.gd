extends RefCounted

## `Dictionary[K, V]` is a dictionary like `Dictionary`: keys read through a dot are not renamed.
## So is a variable that `:=` gives what a function returns, which is declared to be a Dictionary.

var td_health : int = 1
var td_plain : Dictionary = { "td_health": 5 }
var td_typed : Dictionary[String, int] = { "td_health": 10 }

func total(td_values : Dictionary[String, int]) -> int:
	return td_values.td_health + td_health

func td_read() -> Dictionary:
	return { "td_health": 20 }

func td_read_typed() -> Dictionary[String, int]:
	return { "td_health": 30 }

func td_object() -> td_inner:
	return td_inner.new()

class td_inner:
	var td_health : int = 40

func run_case() -> String:
	if td_plain.td_health != 5:
		return "plain"
	if td_typed.td_health != 10:
		return "typed member"
	if total(td_typed) != 11:
		return "typed parameter"
	var read := td_read()
	var read_typed := td_read_typed()
	var later := td_read_later()
	if read.td_health != 20 or read_typed.td_health != 30 or later.td_health != 50:
		return "a variable given what a function returns: %s %s %s" % [read, read_typed, later]
	var inferred := { "td_health": 60 }
	if inferred.td_health != 60:
		return "a variable given a dictionary with :="
	# Not a dictionary, whose member is renamed along with the one it is
	var object := td_object()
	if object.td_health != 40:
		return "a variable given an object a function returns"
	return "ok"

func td_read_later() -> Dictionary:
	return { "td_health": 50 }
