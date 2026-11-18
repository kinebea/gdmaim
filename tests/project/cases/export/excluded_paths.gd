extends RefCounted

## Exclusion paths name a file or a folder, with or without res:// ahead of them.
## The configurations exclude `cases/export/left_alone.gd` and `res://cases/export/excluded`.

func run_case() -> String:
	var in_folder = load("res://cases/export/excluded/in_folder.gd").new()
	var left_alone = load("res://cases/export/left_alone.gd").new()
	var beside = load("res://cases/export/excluded_beside.gd").new()
	if in_folder.get("ex_in_folder") != 22:
		return "script in an excluded folder was renamed"
	if left_alone.get("ex_left_alone") != 11:
		return "script excluded without res:// was renamed"
	if OS.has_feature("renamed") and beside.get("ex_beside") != null:
		return "script whose path begins like an excluded folder was excluded too"
	return "ok" if beside.ex_beside == 33 else "ex_beside"
