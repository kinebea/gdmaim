extends Node

## Operators next to each other are separate tokens.
## `!%OpsPanel` was read as the operator `!%` and a name, which got renamed like the class below.

class OpsPanel:
	var ops_shown : bool = true

func run_case() -> String:
	var panel := Control.new()
	panel.name = "OpsPanel"
	add_child(panel)
	panel.owner = self
	panel.unique_name_in_owner = true

	var hidden : bool = !%OpsPanel.visible
	if hidden:
		return "unique name behind ! not found"
	var count : int = 3
	var negative : int=-count
	var product : int = count*-count
	var same : bool = count==-negative
	if negative != -3 or product != -9 or !same:
		return "operators changed: %s %s %s" % [negative, product, same]
	if !OpsPanel.new().ops_shown:
		return "inner class"
	return "ok"
