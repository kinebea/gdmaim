extends RefCounted

## Strip Lines Matching RegEx goes by the source lines and removes whole statements.
## The configurations filter with `DEBUG_ONLY|(?<!func )rf_trace[(]|print_debug[(]`.

var rf_log : Array = []

func rf_trace(text : String) -> void:
	rf_log.append(text)

func only_statement() -> void:
	print_debug("the only statement of its function")

func in_else(value : int) -> int:
	if value > 0:
		return value
	else:
		print_debug(value)
	return 0

func spread() -> int:
	rf_trace(
		"a statement"
	)
	rf_log.append("kept")
	return rf_log.size()

func by_comment() -> int:
	var total : int = 1
	total += 10 # DEBUG_ONLY
	return total

func run_case() -> String:
	only_statement()
	if in_else(3) != 3 or in_else(-3) != 0:
		return "only statement of a block"
	var filtered : bool = OS.has_feature("postprocessed")
	if spread() != (1 if filtered else 2) or rf_log.back() != "kept":
		return "statement over several lines: " + str(rf_log)
	if by_comment() != (1 if filtered else 11):
		return "line matched by its comment: %d" % by_comment()
	return "ok"
