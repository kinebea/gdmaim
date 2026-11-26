class_name CnBase extends RefCounted

## Used by cases/parser/class_names.gd, and the members named td_ by cases/parser/typed_dictionary.gd

const CN_LIMIT : int = 3

var cn_size : int = 1

static func cn_make(size : int) -> CnBase:
	var made : CnBase = CnBase.new()
	made.cn_size = size
	return made

func cn_describe() -> String:
	return "base" + str(cn_size)

static func td_make() -> Dictionary:
	return { "td_health": 70 }

static var td_table : Dictionary = { "td_health": 110 }
const TD_CONSTANT := { "td_health": 120 }
