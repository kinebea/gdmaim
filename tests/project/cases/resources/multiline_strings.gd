extends RefCounted

## The text of a string that spans lines is left alone, and what follows it is still read.
## The strings hold lines that look like a section and like a property named after a variable.

func run_case() -> String:
	var scene : Node = load("res://cases/resources/data/multiline_label.tscn").instantiate()
	var dialog : Node = scene.get_node("Dialog")
	var from_scene : Array = [dialog.text, dialog.speed_zq, dialog.title_zq]
	scene.free()
	if from_scene != ["Welcome!\n[b]Press start[/b]", 3.0, "T"]:
		return "node with a property after its text: " + str(from_scene)

	var item : Resource = load("res://cases/resources/data/multiline_item.tres")
	if item.desc_zq != "Line one\n[b]bold[/b] two" or item.power_zq != 5:
		return "resource with a property after its text: %s %s" % [item.desc_zq.c_escape(), item.power_zq]

	var note : Node = load("res://cases/resources/data/multiline_note.tscn").instantiate()
	var from_note : Array = [note.note_zq, note.after_zq]
	note.free()
	if from_note != ["first\n" + "speed" + "_zq = fast\nend", 9]:
		return "text with a line like a property: " + str(from_note).c_escape()
	return "ok"
