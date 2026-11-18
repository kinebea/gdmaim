extends RefCounted

## A line removed with its annotation is done with: the filters after it
## once went on to remove the line that had taken its place.
## The configurations filter lines holding DEBUG_ONLY.

@export_group("DEBUG_ONLY")
@export var rl_speed : int = 3
@export_category("DEBUG_ONLY as well")
var rl_other : int = 1

func run_case() -> String:
	return "ok" if rl_speed == 3 and rl_other == 1 else "wrong"
