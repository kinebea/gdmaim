extends RefCounted

## A variable set to a dictionary literal is a Dictionary without saying so:
## `stats.dl_speed` reads a key, not the member of the same name.

var dl_speed : int = 1
var dl_defaults = { "dl_speed": 2 }

func run_case() -> String:
	var stats = { "dl_speed": 4, "dl_label": "fast" }
	if stats.dl_speed != 4 or stats.dl_label != "fast":
		return "local"
	stats.dl_speed = 6
	if stats["dl_speed"] != 6:
		return "write through the dot went to another key: " + str(stats.keys())
	if dl_defaults.dl_speed != 2:
		return "member"
	return "ok" if dl_speed == 1 else "dl_speed"
