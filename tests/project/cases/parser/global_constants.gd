extends RefCounted

## A script may declare a constant or an enum with the name of one of @GlobalScope, as GcShadow does.
## Every other script still reads the one of @GlobalScope with that name.

func run_case() -> String:
	if ERR_UNCONFIGURED != 3 or KEY_SPACE != 32:
		return "constant of @GlobalScope: %d %d" % [ERR_UNCONFIGURED, KEY_SPACE]
	var side : Side = SIDE_RIGHT
	if side != 2:
		return "enum of @GlobalScope: %d" % side
	if GcShadow.ERR_UNCONFIGURED != -999 or GcShadow.KEY_SPACE != -32 or GcShadow.gc_code() != -999:
		return "constant with the name of one of @GlobalScope: %d %d" % [GcShadow.ERR_UNCONFIGURED, GcShadow.gc_code()]
	if GcShadow.gc_side() != GcShadow.Side.GC_BOTTOM or GcShadow.gc_side() != 1:
		return "enum with the name of one of @GlobalScope: %d" % GcShadow.gc_side()
	return "ok"
