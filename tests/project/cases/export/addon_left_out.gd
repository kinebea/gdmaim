extends RefCounted

## The addon is not part of the game, however the project got exported.

func run_case() -> String:
	for file in ["plugin.cfg", "plugin.gd", "export_plugin.gd", "settings.gd"]:
		for suffix in ["", ".remap", "c"]:
			if FileAccess.file_exists("res://addons/gdmaim/" + file + suffix):
				return "addons/gdmaim/%s is in the pack" % (file + suffix)
	return "ok"
