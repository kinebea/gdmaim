extends RefCounted

## ##FEATURE_FUNC leaves a stub of a function if the export does not have the feature.
## No configuration has the feature "ff_missing". Those that filter have "postprocessed".

enum FfMode { FF_IDLE, FF_BUSY }

class FfThing:
	var ff_tag : int = 1

##FEATURE_FUNC ff_missing
func stub_int() -> int:
	return 4242

##FEATURE_FUNC ff_missing
func stub_node() -> Node:
	return Engine.get_main_loop().root

##FEATURE_FUNC ff_missing
func stub_enum() -> FfMode:
	return FfMode.FF_BUSY

##FEATURE_FUNC ff_missing
func stub_class() -> FfThing:
	return FfThing.new()

##FEATURE_FUNC ff_missing
func stub_spread(
	first : int,
	second : int
) -> int:
	return first + second + 4242

##FEATURE_FUNC ff_missing
func stub_one_line() -> bool: return true
func after_one_line() -> int:
	return 5

##FEATURE_FUNC ff_missing
func stub_blank_line() -> int:

	return 7

##FEATURE_FUNC postprocessed
func kept() -> int:
	return 42

func run_case() -> String:
	if after_one_line() != 5:
		return "the function after a stub with its body on one line"
	var secret : int = 42 * 101
	if !OS.has_feature("postprocessed"):
		if stub_int() != secret or stub_spread(1, 2) != secret + 3 or !stub_one_line() or stub_blank_line() != 7:
			return "functions changed without filtering"
		return "ok"
	if kept() != 42:
		return "a function of a feature the export has was replaced"
	if stub_int() != 0:
		return "the function is still there"
	if stub_node() != null or stub_class() != null or stub_enum() == FfMode.FF_BUSY:
		return "stub returning a node, a class or an enum"
	if stub_spread(1, 2) != 0:
		return "stub with its parameters on several lines"
	if stub_one_line() or stub_blank_line() != 0:
		return "stub with its body on one line, or behind an empty line"
	var exported : String = FileAccess.get_file_as_string("res://cases/postprocess/feature_func.gd")
	if exported.contains(str(42).repeat(2)):
		return "the body is still in the exported script"
	return "ok"
