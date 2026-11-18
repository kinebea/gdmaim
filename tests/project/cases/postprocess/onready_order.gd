extends Node
@onready var oo_parent : Node = get_parent()
@onready var oo_name : String = oo_parent.name
@onready var oo_length : int = oo_name.length()
@onready var oo_double : int = oo_length * 2
@onready var oo_text : String = str(oo_double)

## @onready variables keep their order when the top-level declarations are shuffled.
## There is no empty line between them, nor ahead of them.

signal oo_changed

func run_case() -> String:
	oo_changed.emit()
	var expected : String = str(String(get_parent().name).length() * 2)
	return "ok" if oo_text == expected else "got '%s' for '%s'" % [oo_text, expected]
