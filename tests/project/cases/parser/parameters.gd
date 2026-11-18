extends RefCounted

## Default values may hold commas and may use the parameters ahead of them.

enum PaKind { PA_GRUNT, PA_BOSS }

const PA_LOW : int = 1
const PA_HIGH : int = 2

func with_array(pa_kinds : Array = [PaKind.PA_GRUNT, PaKind.PA_BOSS], pa_extra : int = 1) -> int:
	return pa_kinds.size() + pa_extra

func with_dictionary(pa_options : Dictionary = {"low": PA_LOW, "high": PA_HIGH}, pa_scale : int = 1) -> int:
	return (pa_options["low"] + pa_options["high"]) * pa_scale

func with_call(pa_origin : Vector2 = Vector2(maxi(1, 2), 3), pa_factor : float = 2.0) -> float:
	return pa_origin.x * pa_factor

func with_earlier(pa_first, pa_second = pa_first, pa_third = [pa_first, pa_second]):
	return [pa_second, pa_third]

func run_case() -> String:
	if with_array() != 3 or with_array([], 5) != 5:
		return "array as a default value"
	if with_dictionary() != 3 or with_dictionary({"low": 2, "high": 2}, 2) != 8:
		return "dictionary as a default value"
	if with_call() != 4.0 or with_call(Vector2(3, 0), 3.0) != 9.0:
		return "call as a default value"
	if with_earlier(4) != [4, [4, 4]]:
		return "default value using an earlier parameter: " + str(with_earlier(4))
	return "ok"
