extends RefCounted

## Enum values set to other values, and comments inside an enum.

signal en_changed

enum EnTeam { EN_RED, EN_BLUE, EN_DEFAULT = EN_RED }

var en_score : int = 0

enum EnKeys { EN_UP = KEY_UP, EN_DOWN = KEY_DOWN }

var en_after : int = 2

enum EnFlags {
	EN_A = 1, # the first
	EN_B = 2,
	EN_ALL = EN_A | EN_B,
	EN_NONE = 0,
}

enum EnSaved {
	##START_LOCK_SYMBOLS
	EN_KEPT_A,
	EN_KEPT_B,
	##END_LOCK_SYMBOLS
	EN_LAST = EN_KEPT_A
}

func bump() -> int:
	en_changed.emit()
	en_score += 1
	return en_score

func run_case() -> String:
	if bump() != 1 or en_after != 2:
		return "members declared after an enum"
	if EnTeam.EN_DEFAULT != 0 or EnKeys.EN_DOWN != KEY_DOWN:
		return "value set to another value"
	if EnFlags.EN_ALL + EnFlags.EN_NONE + EnSaved.EN_LAST != 3:
		return "value set to an expression"
	var names : Array = EnSaved.keys()
	if !names.has("EN_KEPT_A") or !names.has("EN_KEPT_B"):
		return "hints inside an enum: " + str(names)
	return "ok"
