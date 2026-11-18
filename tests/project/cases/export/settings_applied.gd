extends RefCounted

## The export did what its configuration says: the feature tags "renamed", "postprocessed"
## and "binary" are those of the configuration, see tests/README.md.
## Enable Obfuscation only decides on renaming, post-processing takes place without it.

# SA_COMMENT_MARKER

var sa_probe : int = 1

func run_case() -> String:
	var renamed : bool = get("sa_probe") == null
	if renamed != OS.has_feature("renamed"):
		return "names are renamed" if renamed else "names are not renamed"
	var exported : String = FileAccess.get_file_as_string("res://cases/export/settings_applied.gd")
	if OS.has_feature("binary"):
		# GDMaim exports binary tokens itself, which leaves no text to look at
		if !exported.is_empty() or !FileAccess.file_exists("res://cases/export/settings_applied.gdc"):
			return "the script is not exported as binary tokens"
		return "ok" if sa_probe == 1 else "sa_probe"
	if exported.is_empty() and OS.has_feature("postprocessed"):
		return "the script cannot be read from the pack"
	# A preset that exports binary tokens leaves no text to look at
	var stripped : bool = !exported.is_empty() and !exported.contains("SA_" + "COMMENT_MARKER")
	if stripped != OS.has_feature("postprocessed"):
		return "comments are stripped" if stripped else "comments are not stripped"
	return "ok" if sa_probe == 1 else "sa_probe"
