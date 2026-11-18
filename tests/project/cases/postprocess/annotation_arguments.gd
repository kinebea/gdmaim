extends RefCounted

## The arguments of an annotation may hold brackets and may span lines.

@export_range(
	0.0,
	10.0
) var aa_speed : float = 1.0

@export_range(
	0.0,
	10.0,
) var aa_trailing_comma : float = 2.0

@export_enum(
	"Warrior", "Mage"
) var aa_job : int

@export_range(0, (1 << 4) - 1) var aa_mask : int = 4

@warning_ignore(
	"unused_parameter",
	"unused_variable"
)
func ignored(aa_unused : int) -> int:
	var aa_also_unused : int = 3
	return 9

@warning_ignore("integer_division", ("unused_variable"))
func divided() -> int:
	return 7 / 2

func run_case() -> String:
	if aa_speed != 1.0 or aa_trailing_comma != 2.0 or aa_job != 0:
		return "arguments on several lines"
	if aa_mask != 4:
		return "arguments with brackets"
	if ignored(1) != 9 or divided() != 3:
		return "@warning_ignore"
	return "ok"
