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

class TdBase:
	var td_data : Dictionary = { "td_health": 100 }

class TdDerived extends TdBase:
	func td_derived_read() -> int:
		return td_data.td_health

class TdFurther extends TdDerived:
	func td_further_read() -> int:
		return self.td_data.td_health + td_data.td_health

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
	var made := CnBase.td_make()
	if made.td_health != 70:
		return "a variable given what a static function of another class returns: %s" % made
	var made_object := CnBase.cn_make(80)
	if made_object.cn_size != 80:
		return "a variable given an object a static function of another class returns"
	var settings := Boot.boot_settings()
	if settings.boot_level != 90:
		return "a variable given what a function of an autoload returns: %s" % settings
	if TdDerived.new().td_derived_read() != 100 or TdFurther.new().td_further_read() != 200:
		return "a dictionary that an inner class has from the inner class it extends"
	# Not a dictionary, whose member is renamed along with the one it is
	var object := td_object()
	if object.td_health != 40:
		return "a variable given an object a function returns"
	return "ok"

func td_read_later() -> Dictionary:
	return { "td_health": 50 }
