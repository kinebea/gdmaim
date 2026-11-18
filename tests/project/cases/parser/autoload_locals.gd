extends RefCounted

## A local of a function of an autoload is not a member of it.
## boot_load() has a local named like the member read here.

func run_case() -> String:
	if Boot.boot_load("abc") != 3:
		return "boot_load"
	Boot.boot_level += 1
	if Boot.boot_level != 2:
		return "member named like a local"
	Boot.boot_level = 1
	return "ok"
