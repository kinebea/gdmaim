extends RefCounted

## Strip Static Typing takes the types away and leaves everything else as it is.
## The configuration "strip_typing" exports with it.

signal st_hit(amount : int, source : String)

enum StMode { ST_IDLE, ST_BUSY }

@export var st_exported : int = 5
var st_mode : StMode
var st_count : int
var st_ease : Tween.EaseType = Tween.EASE_OUT
var st_origin : Vector2 = Vector2(1, 2)
var st_value : int = 0:
	set(new_value): st_value = clampi(new_value, 0, 10)
var st_list : Array[int] = [4]

func typed_array() -> Array[int]:
	return [1, 2]

func typed_dictionary() -> Dictionary[String, int]:
	return {"a": 1}

func dotted(transition : Tween.TransitionType = Tween.TRANS_SINE) -> Tween.TransitionType:
	return transition

func mixed(first : int, second, third : bool = false, offset : Vector2 = Vector2(st_origin.x, 0.0)) -> float:
	return 0.0 if third else first + second + offset.x

func one_line(amount : int) -> int: return amount * 2

func inline_bodies(limit : int) -> int:
	var total : int = 0
	for i : int in limit: total += i
	if total > 2: total += 10
	else: total -= 10
	var twice : Callable = func(value : int) -> int: return value * 2
	return twice.call(total)

func run_case() -> String:
	if typed_array() != [1, 2] or typed_dictionary() != {"a": 1}:
		return "return type with brackets"
	if dotted() != Tween.TRANS_SINE or st_ease != Tween.EASE_OUT:
		return "type with a dot"
	if mixed(1, 2) != 4.0 or mixed(1, 2, true) != 0.0 or mixed(1, 2, false, Vector2(5, 0)) != 8.0:
		return "typed and untyped parameters"
	if one_line(4) != 8 or inline_bodies(4) != 32 or inline_bodies(2) != -18:
		return "body on the line of its statement"
	st_value = 50
	if st_value != 10:
		return "setter on one line"
	var received : Array[int] = []
	st_hit.connect(func(amount : int, _source : String) -> void: received.append(amount))
	st_hit.emit(3, "test")
	if received != [3] or st_list != [4]:
		return "signal with typed parameters"
	if st_mode != StMode.ST_IDLE or st_count != 0 or st_exported != 5:
		return "variable without a value: %s %s" % [st_mode, st_count]
	if OS.has_feature("untyped"):
		var exported : String = FileAccess.get_file_as_string("res://cases/postprocess/strip_typing.gd")
		if exported.contains("Array" + "[int]") or exported.contains("Tween." + "TransitionType") or exported.contains("-" + ">"):
			return "types are still in the exported script"
	return "ok"
