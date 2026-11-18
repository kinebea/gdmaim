extends RefCounted

## A script with a class_name is found by that name, also after it got renamed: as a type,
## as a base class, and for its constants, enums, static functions and inner classes.

var cn_typed : CnBase = CnDerived.new()

func run_case() -> String:
	var made : CnBase = CnBase.cn_make(4)
	if made.cn_describe() != "base4" or CnBase.CN_LIMIT != 3:
		return "static function or constant of a class"
	if !(cn_typed is CnDerived) or made is CnDerived:
		return "is with the name of a class"
	if cn_typed.cn_describe() != "derived1base1":
		return "method of the base class"
	if CnDerived.CnKind.CN_FANCY != 1 or CnDerived.CnInner.new().cn_value != 5:
		return "enum or inner class of a class"
	var derived : CnDerived = cn_typed as CnDerived
	if derived == null:
		return "as with the name of a class"
	var global_name : String = (cn_typed.get_script() as Script).get_global_name()
	if OS.has_feature("renamed") == (global_name == "CnDerived"):
		return "the class is called " + global_name
	return "ok"
