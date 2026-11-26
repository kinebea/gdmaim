## The annotations of the script as a whole stay ahead of `extends`, whatever gets shuffled.
@static_unload
extends RefCounted

static var sa_count : int = 3

func sa_first() -> int:
	return 1

func sa_second() -> int:
	return 2

func run_case() -> String:
	if sa_count + sa_first() + sa_second() != 6:
		return "the members of the script"
	return "ok"
