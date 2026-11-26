extends RefCounted

## The arguments of an annotation may hold brackets and may span lines. The names in them are
## renamed along with what they name.

const AA_LIMIT : int = 7
enum AaSize { AA_SMALL, AA_BIG = 12 }

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

@export_range(0, AA_LIMIT) var aa_limited : int = 5

@export_range(AaSize.AA_SMALL, AaSize.AA_BIG, CnBase.CN_LIMIT) var aa_sized : int = 6

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
	if aa_limited != 5 or aa_sized != 6:
		return "arguments that name a constant"
	if ignored(1) != 9 or divided() != 3:
		return "@warning_ignore"
	return "ok"
