extends Node

## A node path ends where it actually ends: a quoted one at its closing quote, whatever is in between,
## and an unquoted one ahead of the operator that follows it.

class NpBar:
	var np_tag : int = 1

var np_expected : float = 0.0

func add_node(parent : Node, node_name : String, unique : bool = false) -> Node:
	var node := ProgressBar.new()
	node.name = node_name
	parent.add_child(node)
	node.owner = self
	node.unique_name_in_owner = unique
	return node

func run_case() -> String:
	add_node(self, "Enemy (2)")
	add_node(self, "Bob's Node")
	var items : Node = add_node(self, "NpItems")
	add_node(items, "Sword, Iron")
	add_node(items, "NpBar", true)

	$"Enemy (2)".set_meta("seen", true)
	var text : String = "a, b # c"
	if text != "a, b # c" or !$"Enemy (2)".has_meta("seen"):
		return "quoted path with brackets"
	if $"Bob's Node" == null or $'NpItems/Sword, Iron' == null or $"NpItems/Sword, Iron" == null:
		return "quoted path with an apostrophe or a comma"

	var same : bool = %NpBar.value==np_expected
	var same_path : bool = $NpItems/NpBar.value==np_expected
	var differs : bool = $NpItems/NpBar.value!=np_expected
	if !same or !same_path or differs:
		return "operator after an unquoted path"
	if NpBar.new().np_tag != 1:
		return "inner class"
	return "ok"
