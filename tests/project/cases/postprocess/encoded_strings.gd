extends RefCounted

## Encode Strings has the strings of a script exported encoded, and decoded when the game runs.
## The configurations with the feature tag `encoded` turn it on. Whatever it does to a string, the
## value has to stay, and a string that has to be a constant must be left as it is.
##
## What a string has to be is put together from two halves here, so that the whole of it is
## nowhere else in this file.

const ES_CONSTANT : String = "es constant kept"
const ES_LIST : Array = ["es list kept"]

@export var es_exported : String = "es exported kept"
@export_enum("es enum kept", "es enum other") var es_choice : String = "es enum kept"

var es_member : String = "es member text"
var es_single := 'es single "quoted" text'
static var es_static : String = "es static text"
var es_name : StringName = &"es_name_kept"
var es_path : NodePath = ^"es/path/kept"
var es_raw : String = r"es raw\n kept"
var es_long : String = """es long
kept"""

func es_default(text : String = "es default kept") -> String:
	return text

func es_string_name() -> StringName:
	return "es_returned_name"

func es_matched(value : String) -> String:
	match value:
		"es first pattern":
			return "es first branch"
		"es second pattern", "es third pattern":
			return "es other branch"
	return "es no branch"

func es_wide(value : Array) -> String:
	match value:
		["es wide pattern",
			"es wide second"]:
			return "es wide branch"
	return "es wide other"

func es_local() -> String:
	const ES_LOCAL : String = "es local kept"
	return ES_LOCAL + " es local text"

func es_plain() -> String:
	var hinted : String = "es hint kept" ##PLAIN_STRINGS
	##START_PLAIN_STRINGS
	var first : String = "es section kept"
	var second : String = "es section second"
	##END_PLAIN_STRINGS
	return hinted + first + second + "es after section"

func es_escapes() -> String:
	return "es tab\there, \"quotes\", back\\slash, line\nbreak, é\U01F600"

func es_inline(first : bool) -> String:
	return"es inline text"if first else"es inline other"

func es_in_brackets() -> Array:
	return [
		"es bracket text",
		func(value : String) -> String:
			match value:
				"es lambda pattern":
					return "es lambda branch"
			return "es lambda other",
		func() -> String:
			const ES_INNER : String = "es inner kept"
			return ES_INNER,
	]

func run_case() -> String:
	if es_member != "es mem" + "ber text" or es_single != "es single " + char(34) + "quoted" + char(34) + " text" or es_static != "es sta" + "tic text":
		return "a variable: " + es_member + ", " + es_single + ", " + es_static
	if ES_CONSTANT != "es const" + "ant kept" or ES_LIST[0] != "es li" + "st kept" or es_exported != "es expor" + "ted kept" or es_choice != "es en" + "um kept":
		return "a constant or an exported variable"
	if es_name != &"es_name_kept" or es_path != ^"es/path/kept" or es_raw != "es raw" + char(92) + "n kept" or es_long != "es long" + char(10) + "kept":
		return "a StringName, a NodePath, a raw or a long string"
	if es_default() != "es def" + "ault kept" or es_default("es given text") != "es giv" + "en text":
		return "an argument"
	if String(es_string_name()) != "es_retur" + "ned_name":
		return "a StringName that is returned: " + es_string_name()
	if es_matched("es first" + " pattern") != "es fir" + "st branch" or es_matched("es third" + " pattern") != "es oth" + "er branch" or es_matched("none") != "es n" + "o branch":
		return "a match"
	var escapes : String = "es tab" + char(9) + "here, " + char(34) + "quotes" + char(34) + ", back" + char(92) + "slash, line" + char(10) + "break, " + char(0xe9) + char(0x1f600)
	if es_escapes() != escapes:
		return "escapes: " + es_escapes().c_escape()
	if es_inline(true) != "es inl" + "ine text" or es_inline(false) != "es inl" + "ine other":
		return "a string right after a keyword"
	var in_brackets : Array = es_in_brackets()
	if in_brackets[0] != "es brac" + "ket text" or in_brackets[1].call("es lambda" + " pattern") != "es lam" + "bda branch" or in_brackets[1].call("none") != "es lam" + "bda other":
		return "strings inside brackets"
	if in_brackets[2].call() != "es inn" + "er kept" or es_local() != "es loc" + "al kept es local text":
		return "a constant of a function"
	if es_plain() != "es hi" + "nt keptes sec" + "tion keptes sec" + "tion secondes aft" + "er section":
		return "a string kept plain by a hint"
	if es_wide(["es wide" + " pattern", "es wide" + " second"]) != "es wi" + "de branch" or es_wide([]) != "es wi" + "de other":
		return "a pattern over several lines"
	if "es %s of %d" % ["format", 2] != "es for" + "mat of 2" or "es length".length() != 9 or !{"es key": 1}.has("es" + " key") or !("es" in "es inside"):
		return "a string in an expression"

	# The export, where there is text to look at
	var exported : String = FileAccess.get_file_as_string("res://cases/postprocess/encoded_strings.gd")
	if exported.is_empty():
		return "ok"
	var plain : bool = exported.contains("es mem" + "ber text")
	if plain == OS.has_feature("encoded"):
		return "strings are not encoded" if plain else "strings are encoded"
	for encoded in ["es sin" + "gle ", "es sta" + "tic text", "es_retur" + "ned_name", "es fir" + "st branch", "es tab", "es inl" + "ine text", "es brac" + "ket text", "es lam" + "bda other", "es %" + "s of","es len" + "gth", "es k" + "ey", "es ins" + "ide", "es aft" + "er section"]:
		if exported.contains(encoded) == OS.has_feature("encoded"):
			return "'%s' is %s" % [encoded, "not encoded" if OS.has_feature("encoded") else "encoded"]
	for kept in ["es const" + "ant kept", "es li" + "st kept", "es expor" + "ted kept", "es en" + "um kept", "es_na" + "me_kept", "es/pa" + "th/kept", "es r" + "aw", "es lo" + "ng", "es def" + "ault kept", "es fir" + "st pattern", "es thi" + "rd pattern", "es lam" + "bda pattern", "es wide" + " second", "es loc" + "al kept", "es inn" + "er kept", "es hi" + "nt kept", "es sec" + "tion kept", "es sec" + "tion second"]:
		if !exported.contains(kept):
			return "'%s' is not left as it is" % kept
	return "ok"
