extends Node

## An annotation on a line of its own stays with the declaration below it.

signal al_changed

@onready
var al_parent : Node = get_parent()

@export
var al_exported : int = 3

@warning_ignore("unused_parameter")
func ignored(al_unused : int) -> int:
	return 9

@rpc("any_peer")
func remote() -> void:
	al_changed.emit()

func other() -> int:
	return 3

func run_case() -> String:
	if al_parent != get_parent():
		return "@onready above its variable"
	if al_exported != 3 or ignored(1) != 9 or other() != 3:
		return "@export or @warning_ignore above its declaration"
	var config : Dictionary = get_script().get_rpc_config()
	if config.size() != 1:
		return "@rpc above its function: " + str(config)
	return "ok"
