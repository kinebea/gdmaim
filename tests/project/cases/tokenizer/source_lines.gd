extends RefCounted

## The source map leads from every exported line back to the line it came from.
## tests/check_source_map.gd looks up the strings beginning with "mark:" in the source map.

func add(first, second):
	return first + second

func spread_call():
	var sum = add(1,
		2)
	return str(sum) + "mark:after a call over two lines"

func continued():
	var sum = 1 + \
		2
	return str(sum) + "mark:after a continued line"

func long_text():
	var text = """one
two
three"""
	return text + "mark:after a multi-line string"

func listed():
	var list = [
		1,
		2,
	]
	return str(list.size()) + "mark:after an array over four lines"

func last():
	return "mark:last function"

func run_case() -> String:
	if !spread_call().begins_with("3") or !continued().begins_with("3"):
		return "sums"
	if !long_text().begins_with("one\ntwo\nthree") or !listed().begins_with("2"):
		return "text or list"
	return "ok" if last().ends_with("last function") else "last"
