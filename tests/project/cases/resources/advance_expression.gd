extends RefCounted

## The expression of a transition of an AnimationTree uses the members of a script by name.

func run_case() -> String:
	var actor : Node = load("res://cases/resources/data/animation_tree.tscn").instantiate()
	var text : String = actor.get_node("AnimationTree").tree_root.get_transition(0).advance_expression
	var expression := Expression.new()
	var parsed : int = expression.parse(text)
	var value = expression.execute([], actor, false)
	var failed : bool = expression.has_execute_failed()
	actor.free()
	if parsed != OK or failed or value != true:
		return "'%s' does not evaluate on the node" % text
	return "ok"
