extends Node

## Operators next to each other are separate tokens.
## `!%OpsPanel` was read as the operator `!%` and a name, which got renamed like the class below.
## Inside brackets, Godot reads a + or - that begins a line as the sign of the number right behind it,
## and then finds two values in a row: the space between them has to stay.

const OPS_PAD := 22.0

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
	var spread : float = maxf(1.0, count
		+ 2.0)
	var padded : float = maxf(-100.0, count
		- OPS_PAD * 2.0)
	if spread != 5.0 or padded != -41.0:
		return "sign that begins a line inside brackets: %s %s" % [spread, padded]
	if !OpsPanel.new().ops_shown:
		return "inner class"
	return "ok"
