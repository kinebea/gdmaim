class_name GcShadow extends RefCounted

## Used by cases/parser/global_constants.gd: a constant and an enum with the names of ones of @GlobalScope

@warning_ignore("shadowed_global_identifier")
const ERR_UNCONFIGURED := -999

@warning_ignore("shadowed_global_identifier")
const KEY_SPACE := -32

enum Side { GC_TOP, GC_BOTTOM }

static func gc_code() -> int:
	return ERR_UNCONFIGURED

static func gc_side() -> int:
	return Side.GC_BOTTOM
