extends RefCounted

## A hint is found wherever it is in a comment, and a section marker may be followed by text.

var ha_saved : int = 1 # goes into the save file ##LOCK_SYMBOLS
##START_LOCK_SYMBOLS these are read by name
var ha_first : int = 2
var ha_second : int = 3
##END_LOCK_SYMBOLS of the names read by name
var ha_free : int = 4

func run_case() -> String:
	if get("ha_saved") != 1:
		return "hint after other text in a comment"
	if get("ha_first") != 2 or get("ha_second") != 3:
		return "section marker followed by text"
	if OS.has_feature("renamed") and get("ha_free") != null:
		return "the section did not end"
	return "ok" if ha_free == 4 else "ha_free"
