extends Node

## After an opening bracket or a separator `%` begins a unique node name, after a closing bracket it is modulo.
## The nodes are named like the classes below, so a name that is not seen as part of a path gets renamed.

class UnBar:
	var un_tag : int = 1

class UnMana:
	var un_tag : int = 2

var un_divisor : int = 4

func add_unique(node_name : String) -> void:
	var node := ProgressBar.new()
	node.name = node_name
	add_child(node)
	node.owner = self
	node.unique_name_in_owner = true

func name_of(node : Node) -> String:
	return "null" if node == null else String(node.name)

func run_case() -> String:
	add_unique("UnBar")
	add_unique("UnMana")
	var failed : Array = []

	var plain = %UnBar
	if plain == null: failed.append("plain")
	if name_of(%UnBar) != "UnBar": failed.append("call argument")
	if !is_same(%UnBar, %UnBar): failed.append("second argument")
	var list : Array = [%UnMana, %UnBar]
	if list[0] == null or list[1] == null: failed.append("array")
	var lookup : Dictionary = {"k": %UnBar}
	if lookup["k"] == null: failed.append("dictionary")
	var glued=%UnBar
	if glued == null: failed.append("glued assignment")
	var inline = null
	if un_divisor > 0: inline = %UnBar
	if inline == null: failed.append("inline if")
	if name_of(
		%UnMana
	) != "UnMana": failed.append("argument on its own line")
	var negated : float = -%UnBar.value
	if negated != 0.0: failed.append("unary minus")

	var numbers : Array = [10, 11]
	var rest : int = (numbers[1]) %un_divisor
	var rest_index : int = numbers[0] %un_divisor
	if rest != 3 or rest_index != 2: failed.append("modulo after a closing bracket")
	if UnBar.new().un_tag + UnMana.new().un_tag != 3: failed.append("inner classes")
	return "ok" if failed.is_empty() else "failed: " + ", ".join(failed)
