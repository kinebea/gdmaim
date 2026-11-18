extends RefCounted

## This file has CRLF line endings, which stay out of the hints and their arguments.

var crlf_kept : int = 9 ##LOCK_SYMBOLS
var crlf_other : int = 1

func run_case() -> String:
	if get("crlf_kept") != 9:
		return "the locked name was renamed"
	if crlf_other != 1:
		return "other"
	return "ok"
