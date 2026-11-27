extends RefCounted

## Syntax that few scripts have: raw strings, guards in match, "is not", super, a static initializer,
## numbers with a base or underscores, a lambda over several lines, unicode escapes and identifiers.

class PsBase:
	func ps_hello() -> String:
		return "base"

class PsDerived extends PsBase:
	func ps_hello() -> String:
		return super.ps_hello() + "+derived"

var ps_value : int = 3
static var ps_static_set : int = 0

static func _static_init() -> void:
	ps_static_set = 7

func ps_match(value : int, limit : int) -> String:
	match value:
		1 when limit > 5:
			return "big one"
		1:
			return "one"
		var other when other > limit:
			return "over"
		_:
			return "other"

func run_case() -> String:
	var raw : String = r"\d+\n"
	if raw.length() != 5:
		return "raw string: %d" % raw.length()
	var raw_quote : String = r'a\'b'
	if raw_quote != "a\\'b":
		return "raw string with a quote: " + raw_quote
	var raw_multi : String = r"""x\y"""
	if raw_multi != "x\\y":
		return "raw multi-line string: " + raw_multi
	if ps_match(1, 9) != "big one" or ps_match(1, 2) != "one" or ps_match(8, 2) != "over" or ps_match(0, 2) != "other":
		return "match guards"
	var node := RefCounted.new()
	if node is not RefCounted or not (2 not in [1, 3]):
		return "is not / not in"
	if 0b1010 != 10 or 0xF_F != 255 or 1_000 != 1000 or 1e-3 != 0.001:
		return "numbers"
	var adder := func(a : int,
			b : int) -> int:
		return a + b
	if adder.call(2, 3) != 5:
		return "lambda over lines"
	if PsDerived.new().ps_hello() != "base+derived":
		return "super"
	if ps_static_set != 7:
		return "static init"
	if "é" != "é" or "\U01F600".length() != 1:
		return "unicode escapes"
	var ñame : int = 4
	if ñame + ps_value != 7:
		return "unicode identifier"
	return "ok"
