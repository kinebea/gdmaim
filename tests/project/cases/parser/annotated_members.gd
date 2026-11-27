@tool
extends Node

## Members with annotations of their own: @rpc, @abstract, @export_storage, typed collections, and a
## tool button, which only a tool script may have: with @tool stripped, the button goes as well.

@abstract class PmShape:
	@abstract func pm_area() -> float

class PmSquare extends PmShape:
	var pm_side : float = 2.0
	func pm_area() -> float:
		return pm_side * pm_side

enum PmMode { PM_FAST, PM_SLOW }

@export var pm_mode : PmMode = PmMode.PM_SLOW
@export_storage var pm_stored : int = 5
@export_tool_button("Do it") var pm_button : Callable = pm_pressed
var pm_table : Dictionary[String, PmSquare] = {}
var pm_shapes : Array[PmShape] = []

@rpc("any_peer", "call_local")
func pm_remote(value : int) -> int:
	return value * 2

func pm_pressed() -> void:
	pm_stored += 1

func run_case() -> String:
	pm_table["a"] = PmSquare.new()
	pm_shapes.append(pm_table["a"])
	if pm_shapes[0].pm_area() != 4.0:
		return "abstract class: %s" % pm_shapes[0].pm_area()
	if pm_mode != PmMode.PM_SLOW or pm_stored != 5:
		return "exported members"
	pm_button.call()
	if pm_stored != 6:
		return "tool button callable"
	if pm_remote(3) != 6:
		return "rpc function"
	var config : Array = get_rpc_config_names()
	if config.size() != 1:
		return "rpc config: %s" % [config]
	var square := pm_table.get("a") as PmSquare
	if square == null or square.pm_side != 2.0:
		return "typed dictionary value"
	return "ok"

func get_rpc_config_names() -> Array:
	return (get_script() as Script).get_rpc_config().keys()
