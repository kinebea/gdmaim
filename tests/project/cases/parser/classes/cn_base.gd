class_name CnBase extends RefCounted

## Used by cases/parser/class_names.gd

const CN_LIMIT : int = 3

var cn_size : int = 1

static func cn_make(size : int) -> CnBase:
	var made : CnBase = CnBase.new()
	made.cn_size = size
	return made

func cn_describe() -> String:
	return "base" + str(cn_size)
