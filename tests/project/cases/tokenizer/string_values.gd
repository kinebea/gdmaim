extends RefCounted

## A string on a line of its own is a comment and may be removed.
## One that follows other tokens is a value, whatever those tokens are.

func help_text() -> String:
	return """line one
line two"""

func documented() -> int:
	"""Docstring as the first statement."""
	var answer : int = 4
	"""A standalone note that is safe to strip."""
	"another one"
	return answer

func pick(flag : bool) -> String:
	var chosen : String = "plain" if flag else """multi
line"""
	return chosen

func joined() -> String:
	return "-".join(["a",
		"b",
		"""c"""])

func run_case() -> String:
	var text = help_text()
	if !(text is String) or text != "line one\nline two":
		return "help_text got: " + str(text)
	if documented() != 4:
		return "documented wrong"
	if pick(false) != "multi\nline" or pick(true) != "plain":
		return "pick wrong"
	if joined() != "a-b-c":
		return "joined got: " + joined()
	return "ok"
