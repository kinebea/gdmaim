extends Node

## A function that gives get() or the like a name that is not written out, which it builds from a
## string and something else or takes from a list of strings, no longer finds the members that get
## renamed. GDMaim warns about it when it exports, which the configurations look for in the output of
## the export, unless what it would find keeps its name. The functions that would not find them are
## never called.

var nv_slot_head : int = 1
var nv_slot_feet : int = 2
var nv_speed : float = 3.0
var nv_locked_slot_hand : int = 4 ##LOCK_SYMBOLS

func nv_not_run(slot : String) -> int:
	var property : String = "nv_slot_" + slot
	return get(property) + get(slot + "_feet")

func nv_not_run_either() -> float:
	var total : float = 0.0
	for property in ["nv_speed", "nv_unknown"]:
		total += get(property)
	return total

# Not warned about: what only a locked member has, strings that are printed, and a name written out
func nv_not_run_at_all(slot : String) -> int:
	var hand : int = get("nv_locked_slot_" + slot)
	print("nv_slot_" + slot, "nv_speed")
	return hand + get("nv_slot_head")

# Not warned about: a function that gives no name that is not written out
func nv_elsewhere(slot : String) -> String:
	return "nv_slot_" + slot + str(["nv_speed"])

func run_case() -> String:
	return "ok"
