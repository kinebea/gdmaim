extends RefCounted

## A scene keeps the resources it depends on: a theme, a texture, a curve and another scene.
## Binary resources that nothing was renamed in are exported as they are.

func run_case() -> String:
	var themed : Control = load("res://cases/resources/data/uses_theme.tscn").instantiate()
	var font_size : int = themed.theme.default_font_size if themed.theme else -1
	themed.free()
	if font_size != 33:
		return "theme of a scene"

	var parent : Node = load("res://cases/resources/data/parent.tscn").instantiate()
	var problem : String = ""
	if parent.get_node_or_null("Child/Inner") == null:
		problem = "scene inside a scene"
	elif parent.get_node("Sprite").texture == null or parent.get_node("Sprite").texture.width != 77:
		problem = "texture of a scene"
	elif parent.get_node("Line").width_curve == null or parent.get_node("Line").width_curve.point_count != 2:
		problem = "binary resource of a scene"
	parent.free()
	if !problem.is_empty():
		return problem

	if !FileAccess.file_exists("res://cases/resources/data/curve.res"):
		return "the binary resource is not in the pack as it was"
	if FileAccess.file_exists("res://cases/resources/data/curve.tres") or FileAccess.file_exists("res://cases/resources/data/curve.res.remap"):
		return "the binary resource was exported as something else"
	return "ok"
