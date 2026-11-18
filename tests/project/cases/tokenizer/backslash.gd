extends RefCounted

## The tokens on either side of a line continuation stay apart.

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

func run_case() -> String:
	if !no_space():
		return "no space ahead of the backslash"
	if !with_space():
		return "space ahead of the backslash"
	if ternary() != 1:
		return "ternary"
	return "ok"
