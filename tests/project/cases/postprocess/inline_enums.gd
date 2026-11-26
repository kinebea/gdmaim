extends RefCounted

## Inline Enums puts the value of a key of an enum where the key is used, which the configurations
## with the feature tag `inlined` turn on. An enum stays what it is wherever it is used as a whole:
## as a type, or for its keys. With the feature tag `inlined_loose`, only the keys of an enum without
## a name are replaced.
##
## The numbers are ones that are nowhere else in this file, to be counted in what got exported.

enum Ie_state { IE_IDLE, IE_WALK, IE_RUN = 50141, IE_JUMP, IE_FALL = -50143, IE_LAND }
enum Ie_flag {
	IE_NONE = 0,
	IE_FIRST = 0x10,
	IE_BOTH = IE_FIRST | 1,
	IE_AFTER,
	IE_LAST = 50147,
}
enum { IE_LOOSE = 50149, IE_NEXT }
enum Ie_other { IE_NONE = 50151, IE_IDLE }

@export var ie_exported : Ie_state = Ie_state.IE_RUN
var ie_current : Ie_state = Ie_state.IE_WALK
var ie_list : Array[Ie_state] = [Ie_state.IE_IDLE, Ie_state.IE_RUN]
var ie_named : Dictionary = { Ie_state.IE_JUMP: "jump" }

func ie_set(state : Ie_state = Ie_state.IE_JUMP) -> Ie_state:
	ie_current = state
	return ie_current

func ie_next() -> Ie_state:
	return Ie_state.IE_LAND

func ie_described(state : Ie_state) -> String:
	match state:
		Ie_state.IE_IDLE:
			return "idle"
		Ie_state.IE_RUN, Ie_state.IE_JUMP:
			return "fast"
		Ie_state.IE_FALL:
			return "falling"
	return "other"

func ie_shadowed() -> int:
	var Ie_flag : Dictionary = { "IE_LAST": 1 }
	return Ie_flag.IE_LAST

func run_case() -> String:
	if Ie_state.IE_IDLE != 0 or Ie_state.IE_WALK != 1 or Ie_state.IE_RUN != 50000 + 141 or Ie_state.IE_JUMP != 50000 + 142:
		return "the keys of an enum, counted on from a value"
	if Ie_state.IE_FALL != -(50000 + 143) or Ie_state.IE_LAND != -(50000 + 142) or self.Ie_state.IE_FALL ** 2 != (50000 + 143) * (50000 + 143):
		return "a value below zero"
	if Ie_flag.IE_FIRST != 16 or Ie_flag.IE_BOTH != 17 or Ie_flag.IE_AFTER != 18 or Ie_flag.IE_LAST != 50000 + 147:
		return "values that are written out or worked out"
	if IE_LOOSE != 50000 + 149 or IE_NEXT != 50000 + 150 or Ie_other.IE_NONE != 50000 + 151 or Ie_other.IE_IDLE != 50000 + 152:
		return "an enum without a name, or keys two enums both have"
	if ie_exported != 50000 + 141 or ie_current != 1 or ie_list != [0, 50000 + 141] or ie_named[50000 + 142] != "jump":
		return "a variable of the type of an enum"
	if ie_set() != 50000 + 142 or ie_set(Ie_state.IE_IDLE) != 0 or ie_next() != -(50000 + 142):
		return "an argument or a result of the type of an enum"
	if ie_described(Ie_state.IE_IDLE) != "idle" or ie_described(Ie_state.IE_JUMP) != "fast" or ie_described(Ie_state.IE_WALK) != "other" or ie_described(Ie_state.IE_FALL) != "falling":
		return "a match"
	# The names of the keys are not looked at, as they are renamed
	if Ie_state.size() != 6 or Ie_state.keys().size() != 6 or Ie_state.find_key(50000 + 141) != Ie_state.keys()[2] or !(1 in Ie_state.values()):
		return "an enum as a whole"
	if ie_shadowed() != 1:
		return "a variable of the name of an enum"

	# The export, where there is text to look at
	var exported : String = FileAccess.get_file_as_string("res://cases/postprocess/inline_enums.gd")
	if exported.is_empty():
		return "ok"
	var inlined : bool = OS.has_feature("inlined")
	var loose : bool = inlined or OS.has_feature("inlined_loose")
	# How often each number is in the script: once where it is declared, and once more wherever it took the place of the key.
	# The last of an entry tells whether the key is one of an enum without a name
	var counts : Array = [
		["50" + "141", 1, 5, false],
		["(-50" + "143)", 0, 4, false],
		["50" + "147", 1, 2, false],
		["50" + "149", 1, 2, true],
		["50" + "151", 1, 2, false],
	]
	for entry in counts:
		var count : int = exported.count(entry[0])
		var expected : int = entry[2] if (loose if entry[3] else inlined) else entry[1]
		if count != expected:
			return "%s is in the exported script %d times, not %d" % [entry[0], count, expected]
	return "ok"
