extends RefCounted

## CSV files stay in the export: one kept as it is, and one imported as a translation.

func run_case() -> String:
	if !FileAccess.file_exists("res://data/table.csv"):
		return "data/table.csv is not in the pack"
	if !FileAccess.get_file_as_string("res://data/table.csv").begins_with("id,name"):
		return "data/table.csv changed"
	if tr("HELLO") != "Hello there":
		return "translation: " + tr("HELLO")
	return "ok"
