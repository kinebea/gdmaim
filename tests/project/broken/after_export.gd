extends RefCounted

## Compiles as it is written, and does not any more once it is exported: the regex filter of the
## configurations removes the line that declares the variable. No case loads this script.
## The configuration `verify` has the export find it.

func total() -> int:
	var bonus_points : int = 2 # DEBUG_ONLY
	return bonus_points + 1
