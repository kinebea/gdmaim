extends RefCounted

## A name is that of the last declaration ahead of its use, in a block around it.

var sc_health : int = 10
var sc_count : int = 7
var sc_item : int = 5

func declared_later() -> int:
	var result : int = 0
	if sc_health > 5:
		result = sc_health
	var sc_health : int = 3
	return result + sc_health

func in_block_beside() -> int:
	for i in 1:
		var sc_count : int = 1
		sc_count += 1
	return sc_count

func iterator() -> int:
	var total : int = 0
	for sc_item in 3:
		total += sc_item
	return total + sc_item

func parameter(sc_late : int) -> int:
	return sc_late * 2

func ahead_of_declaration() -> int:
	return sc_late + parameter(1)

var sc_late : int = 4

# A declaration ends at a semicolon, after which what it declares is known on the same line
func same_line() -> int:
	var sc_node := RefCounted.new(); sc_node.set_meta(&"sc", 1)
	var sc_health : int = 2; sc_health += 1
	const SC_STEP := 5; var sc_stepped := SC_STEP + 1
	return sc_health + sc_node.get_meta(&"sc") + sc_stepped

func run_case() -> String:
	if declared_later() != 13:
		return "local declared after the member was used: %d" % declared_later()
	if in_block_beside() != 7:
		return "local of a block beside the use: %d" % in_block_beside()
	if iterator() != 8:
		return "iterator used after its loop: %d" % iterator()
	if ahead_of_declaration() != 6:
		return "member used ahead of its declaration: %d" % ahead_of_declaration()
	if same_line() != 10 or sc_health != 10:
		return "local used after a semicolon on the line it is declared on: %d %d" % [same_line(), sc_health]
	return "ok"
