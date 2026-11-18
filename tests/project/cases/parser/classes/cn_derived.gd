class_name CnDerived extends CnBase

## Used by cases/parser/class_names.gd

enum CnKind { CN_PLAIN, CN_FANCY }

class CnInner:
	var cn_value : int = 5

func cn_describe() -> String:
	return "derived" + str(cn_size) + super.cn_describe()
