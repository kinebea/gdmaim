extends RefCounted

## Check Exported Scripts loads every script of the game, with the autoloads out of the tree. A static
## variable may be set from an autoload when its script loads, which needs the autoload to still be there.

static var ca_boot_name : String = Boot.name

func run_case() -> String:
	return "ok" if ca_boot_name == "Boot" else "static variable set from an autoload: " + ca_boot_name
