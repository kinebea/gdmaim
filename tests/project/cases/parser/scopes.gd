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

func run_case() -> String:
	if declared_later() != 13:
		return "local declared after the member was used: %d" % declared_later()
	if in_block_beside() != 7:
		return "local of a block beside the use: %d" % in_block_beside()
	if iterator() != 8:
		return "iterator used after its loop: %d" % iterator()
	if ahead_of_declaration() != 6:
		return "member used ahead of its declaration: %d" % ahead_of_declaration()
	return "ok"
