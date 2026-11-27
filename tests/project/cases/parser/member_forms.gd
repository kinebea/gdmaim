extends Node

## Members declared in ways few scripts have: named accessors, an enum without a name, exported enums
## and flags, a static of an inner class, a class through a preloaded constant, a signal awaited.

const PmClasses := preload("res://cases/parser/classes/cn_base.gd")

signal pr_done(value : int)

enum { PR_FIRST = 4, PR_SECOND }

@export_enum("Warrior", "Mage") var pr_role : int = 1
@export_flags("Fire", "Water") var pr_elements : int = 3

var pr_health : int = 10:
	set = pr_set_health, get = pr_get_health
var _pr_health : int = 0

class PrInner:
	static var pr_count : int = 0
	static func pr_bump() -> int:
		pr_count += 1
		return pr_count

func pr_set_health(value : int) -> void:
	_pr_health = clampi(value, 0, 100)

func pr_get_health() -> int:
	return _pr_health

func pr_emit_later() -> void:
	await get_tree().process_frame
	pr_done.emit(PR_SECOND)

func run_case() -> String:
	pr_health = 150
	if pr_health != 100:
		return "property with named accessors: %d" % pr_health
	if PR_FIRST != 4 or PR_SECOND != 5:
		return "enum without a name"
	if pr_role != 1 or pr_elements != 3:
		return "exported enum and flags"
	if PrInner.pr_bump() != 1 or PrInner.pr_bump() != 2:
		return "static of an inner class"
	if PmClasses.cn_make(4).cn_size != 4 or PmClasses.CN_LIMIT != 3:
		return "class through a preloaded constant"
	var text : String = "{pr_health} hp".format({ "pr_health": pr_health })
	if text != "100 hp":
		return "format: " + text
	pr_emit_later()
	var got : int = await pr_done
	if got != 5:
		return "await a signal: %d" % got
	return "ok"
