extends RefCounted

## The name of the source map is printed from _enter_tree of the first autoload. In autoload/boot.gd
## that function has its body on its line, and an inner class ahead of it has one too.

func run_case() -> String:
	if Boot.boot_entered != 1:
		return "_enter_tree of the autoload ran %d times" % Boot.boot_entered
	if !Boot.boot_helper_entered():
		return "_enter_tree of the inner class"
	return "ok"
