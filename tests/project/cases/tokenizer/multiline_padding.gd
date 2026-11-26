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

# Strings that begin with a line break, and lines after them that use the same variable
class MlInner:
	func built() -> String:
		var ml_text : String = ""
		ml_text += """
			<a name="%s" />
			""" % "x"
		ml_text += """
			<b />
			"""
		return ml_text

	func built_prefixed() -> String:
		var __ml_text : String = ""
		__ml_text += """
			<c />
			""" % []
		__ml_text += "d"
		return __ml_text

func run_case() -> String:
	if TOP_LEVEL.length() != 3:
		return "top level"
	if in_function() != 5:
		return "in function"
	if nested() != 3:
		return "nested"
	var inner := MlInner.new()
	if !inner.built().contains("<a name=\"x\" />") or !inner.built().contains("<b />") or !inner.built_prefixed().ends_with("d"):
		return "lines after a string that begins with a line break"
	return "ok"
