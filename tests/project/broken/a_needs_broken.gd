extends RefCounted

## Compiles as it is written and once it is exported, but needs broken/after_export.gd, which does
## not compile any more then. Check Exported Scripts has to tell the one from the other.

const Needed := preload("res://broken/after_export.gd")

func total_twice() -> int:
	return Needed.new().total() * 2
