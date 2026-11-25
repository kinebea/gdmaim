extends RefCounted

## For cases/postprocess/inline_constants.gd: uses a constant of that script by the name it gives
## the script, and has a constant of a name that script has too.

const Constants := preload("res://cases/postprocess/inline_constants.gd")
const IC_SAME : int = 40136

func from_outside() -> int:
	return Constants.IC_LIMIT

func same() -> int:
	return IC_SAME
