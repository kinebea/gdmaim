extends RefCounted

## Variables are initialized in the order they are declared in,
## which shuffling the top-level declarations must not change.

signal mo_changed

static var mo_shared_base : int = 20
static var mo_shared_derived : int = mo_shared_base + 1

var mo_base_a : int = 5
var mo_derived_a : int = mo_base_a * 2
var mo_base_b : int = 7

func first_helper() -> int:
	return mo_derived_a

var mo_derived_b : int = mo_base_b + 1
var mo_base_c : Array = [1, 2, 3]
var mo_derived_c : int = mo_base_c.size()
@export var mo_base_d : String = "x"
var mo_derived_d : String = mo_base_d + "y"
var mo_base_e : float = 2.0
var mo_derived_e : float = mo_base_e * mo_base_e
var mo_base_f : Dictionary = {
	"k": 11,
}
var mo_derived_f : int = mo_base_f["k"] - 1

func second_helper() -> int:
	return mo_derived_b

func run_case() -> String:
	var wrong : Array = []
	if mo_derived_a != 10: wrong.append("a=%s" % mo_derived_a)
	if mo_derived_b != 8: wrong.append("b=%s" % mo_derived_b)
	if mo_derived_c != 3: wrong.append("c=%s" % mo_derived_c)
	if mo_derived_d != "xy": wrong.append("d=%s" % mo_derived_d)
	if mo_derived_e != 4.0: wrong.append("e=%s" % mo_derived_e)
	if mo_derived_f != 10: wrong.append("f=%s" % mo_derived_f)
	if mo_shared_derived != 21: wrong.append("static=%s" % mo_shared_derived)
	if first_helper() != 10 or second_helper() != 8: wrong.append("helpers")
	return "ok" if wrong.is_empty() else "wrong: " + ", ".join(wrong)
