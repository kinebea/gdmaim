extends RefCounted

## ##LOCK_SYMBOLS on a constant counts for that constant, whatever its value spans or is followed by.

const LS_FIRST = 1 ##LOCK_SYMBOLS

const LS_SECOND = 2 ##LOCK_SYMBOLS
var ls_between : int = 0
const LS_SPREAD : Dictionary = { ##LOCK_SYMBOLS
	"a": 1,
}
const LS_LAST = 3 ##LOCK_SYMBOLS
# an ordinary comment
var ls_after : int = 0

##START_LOCK_SYMBOLS
var ls_property : int:
	get:
		return 1
##END_LOCK_SYMBOLS

func run_case() -> String:
	var constants : Dictionary = get_script().get_script_constant_map()
	var renamed : Array = []
	for constant in ["LS_FIRST", "LS_SECOND", "LS_SPREAD", "LS_LAST"]:
		if !constants.has(constant):
			renamed.append(constant)
	if !renamed.is_empty():
		return "renamed despite the hint: " + ", ".join(renamed)
	if get("ls_property") != 1:
		return "property with a getter inside a locked section"
	if OS.has_feature("renamed") and (get("ls_between") != null or get("ls_after") != null):
		return "the hint also locked a variable next to it"
	return "ok"
