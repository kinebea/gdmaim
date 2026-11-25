extends RefCounted

## Inline Constants puts the value of a constant where its name is used, which the configurations
## with the feature tag `inlined` turn on. The value has to be the same one wherever that is done,
## and a name has to stay where it may be the one of something else.
##
## The numbers are ones that are nowhere else in this file, to be counted in what got exported.

const IC_LIMIT : int = 40123
const IC_RATIO := 0.40125
const IC_SCALE : float = 2
const IC_BELOW = -40127
const IC_ON : bool = true
const IC_TITLE : String = "ic title text"
const IC_OFFSET := Vector2(1.40129, -2)
const IC_TINT : Color = Color(0.25, 0.5, 0.40131)
const IC_LIST : Array = [40133]
const IC_DOUBLE : int = IC_LIMIT * 2
const IC_SAME : int = 40135
const IcUser := preload("res://cases/postprocess/data/inline_user.gd")

const IC_SHADE : int = 40141
const IC_PLAIN : String = "ic plain text"
const IC_PROPERTY : String = "ic_hidden" ##OBFUSCATE_STRINGS
##START_OBFUSCATE_STRINGS
const IC_SECTION : String = "ic_covered"
##END_OBFUSCATE_STRINGS

var ic_hidden : int = 7
var ic_covered : int = 8
var ic_accessed : int = 0:
	set(IC_SHADE):
		ic_accessed = IC_SHADE

class Ic_inner:
	const IC_INSIDE : int = 40137

	func inside() -> int:
		return IC_INSIDE + IC_LIMIT

func ic_sum() -> int:
	return IC_LIMIT + self.IC_LIMIT

func ic_power() -> int:
	return IC_BELOW ** 2

func ic_halves(value : int) -> float:
	return value / IC_SCALE

func ic_local() -> int:
	const IC_STEP : int = 40139
	var total : int = 0
	for i in 2:
		total += IC_STEP
	return total

func ic_shadowed(IC_RATIO : int) -> int:
	return IC_RATIO + 1

func ic_default(limit : int = IC_LIMIT) -> int:
	return limit

func ic_matched(value : int) -> String:
	match value:
		IC_LIMIT:
			return "limit"
	return "other"

func ic_matched_other(value) -> String:
	match value:
		IC_BELOW:
			return "below"
		IC_TITLE:
			return "title"
		IC_OFFSET:
			return "offset"
		IC_ON:
			return "on"
	return "other"

func ic_bound(value : int) -> int:
	match value:
		var IC_SHADE:
			return IC_SHADE
	return 0

func ic_shadows() -> Array:
	var result : Array = []
	for IC_SHADE in 2:
		result.append(IC_SHADE)
	var lambda : Callable = func(IC_SHADE : int) -> int: return IC_SHADE
	result.append(lambda.call(5))
	ic_accessed = 6
	result.append(ic_accessed)
	result.append(ic_bound(7))
	if true:
		var IC_SHADE : int = 8
		result.append(IC_SHADE)
	return result

func ic_plain() -> String:
	var text : String = IC_PLAIN ##PLAIN_STRINGS
	##START_PLAIN_STRINGS
	text += IC_PLAIN
	##END_PLAIN_STRINGS
	return text

func run_case() -> String:
	if ic_sum() != 2 * (40000 + 123) or IC_DOUBLE != 2 * (40000 + 123) or ic_default() != 40000 + 123 or ic_matched(40000 + 123) != "limit":
		return "a whole number: %d, %d" % [ic_sum(), IC_DOUBLE]
	if ic_power() != (40000 + 127) * (40000 + 127):
		return "a number below zero taken to a power: %d" % ic_power()
	if !is_equal_approx(ic_halves(5), 2.5):
		return "a float written as a whole number: %s" % ic_halves(5)
	if !is_equal_approx(IC_RATIO * 2, 0.8025) or ic_shadowed(5) != 6:
		return "a float, or a parameter of its name"
	if !IC_ON or IC_TITLE + "!" != "ic title" + " text!":
		return "a bool or a string"
	if !(IC_OFFSET * 2).is_equal_approx(Vector2(2.80258, -4)) or !is_equal_approx(IC_TINT.b, 0.4 + 0.00131):
		return "a vector or a color"
	if IC_LIST[0] != 40000 + 133 or ic_local() != 2 * (40000 + 139) or Ic_inner.new().inside() != 80000 + 260:
		return "a list, a constant of a function or one of an inner class"
	var user := IcUser.new()
	if user.from_outside() != 40000 + 123 or IC_SAME != 40000 + 135 or user.same() != 40000 + 136:
		return "a constant used from another script, or two of one name"

	if ic_matched_other(-(40000 + 127)) != "below" or ic_matched_other("ic title" + " text") != "title" or ic_matched_other(Vector2(1.4 + 0.00129, -2)) != "offset" or ic_matched_other(true) != "on" or ic_matched_other(3) != "other":
		return "a constant as a pattern of a match"
	if ic_shadows() != [0, 1, 5, 6, 7, 8]:
		return "something else of the name of a constant: %s" % [ic_shadows()]
	if ic_plain() != "ic pla" + "in textic pla" + "in text":
		return "a string that is to stay plain"
	if get(IC_PROPERTY) != 7 or get(IC_SECTION) != 8:
		return "a string that is obfuscated where it is declared"
	
	# The export, where there is text to look at
	var exported : String = FileAccess.get_file_as_string("res://cases/postprocess/inline_constants.gd")
	if exported.is_empty():
		return "ok"
	var inlined : bool = OS.has_feature("inlined")
	# How often each number is in the script: once where it is declared, and once more wherever it took the place of the name
	var counts : Array = [
		["40" + "123", 1, 7],
		["0.40" + "125", 1, 2],
		["(-40" + "127)", 0, 2],
		["1.40" + "129", 1, 3],
		["0.40" + "131", 1, 2],
		["40" + "133", 1, 1],
		["40" + "135", 1, 1],
		["40" + "137", 1, 2],
		["40" + "139", 1, 2],
		["40" + "141", 1, 1],
		["ic pla" + "in text", 1, 3],
	]
	for entry in counts:
		var count : int = exported.count(entry[0])
		if count != entry[2 if inlined else 1]:
			return "%s is in the exported script %d times, not %d" % [entry[0], count, entry[2 if inlined else 1]]
	if exported.contains("/2" + ".0") != inlined:
		return "the float written as a whole number is%s inlined" % ("" if !inlined else " not")
	return "ok"
