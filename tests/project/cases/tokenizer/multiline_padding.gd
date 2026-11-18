extends RefCounted

## The lines a multi-line string spans are left empty in the output,
## where they once carried the indentation of the line the string began on.

const TOP_LEVEL = """a
b"""

func in_function() -> int:
	var text = """a
b
c"""
	return text.length()

func nested() -> int:
	var total : int = 0
	for i in 2:
		if i == 1:
			var text = """x
y"""
			total += text.length()
	return total

func run_case() -> String:
	if TOP_LEVEL.length() != 3:
		return "top level"
	if in_function() != 5:
		return "in function"
	if nested() != 3:
		return "nested"
	return "ok"
