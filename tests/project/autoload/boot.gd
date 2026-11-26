extends Node

## The first autoload of the project, which is where GDMaim puts the name of the source map.

class BootHelper extends Node:
	var helper_entered : bool = false
	func _enter_tree() -> void:
		helper_entered = true

var boot_counter : int = 7
var boot_config : Dictionary = { "boot_volume": 3 }
var boot_level : int = 1
var boot_entered : int = 0

func _enter_tree(): boot_entered += 1

func boot_load(path : String) -> int:
	var boot_level : int = path.length()
	return boot_level

func boot_settings() -> Dictionary:
	return { "boot_level": 90 }

func boot_helper_entered() -> bool:
	var helper := BootHelper.new()
	add_child(helper)
	var entered : bool = helper.helper_entered
	helper.free()
	return entered
