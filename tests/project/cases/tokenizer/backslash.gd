extends RefCounted

## The tokens on either side of a line continuation stay apart.
## A line continuation goes on past a line with only a comment on it, as Godot reads it.

var grounded : bool = true
var jumping : bool = true

func no_space() -> bool:
	if grounded\
	and jumping:
		return true
	return false

func with_space() -> bool:
	if grounded \
	and jumping:
		return true
	return false

func ternary() -> int:
	var first : int = 1
	var second : int = 2
	var chosen : int = first if grounded\
		else second
	return chosen

func past_comment() -> String:
	var text : String = "ab"
	text = text \
		# The first letter
		.replace("a", "x") \
		# The second one
		.replace("b", "y")
	return text

func run_case() -> String:
	if !no_space():
		return "no space ahead of the backslash"
	if !with_space():
		return "space ahead of the backslash"
	if past_comment() != "xy":
		return "comment line after a backslash: " + past_comment()
	if ternary() != 1:
		return "ternary"
	return "ok"
