extends RefCounted

## Autoloads keep their name, and their members are known as those of the autoload,
## whether or not the name of the source map gets injected.
## The key read from its dictionary is not the member of that name below.

var boot_volume : int = 9

func run_case() -> String:
	if Boot.boot_counter != 7:
		return "member of an autoload"
	if Boot.boot_config.boot_volume != 3:
		return "key of a dictionary of an autoload"
	if boot_volume != 9:
		return "member named like that key"
	if Engine.get_main_loop().root.get_node_or_null("Boot") == null:
		return "the autoload is not in the tree by its name"
	return "ok"
