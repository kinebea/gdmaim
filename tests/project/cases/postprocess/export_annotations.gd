extends Node

## @export is not only for the editor: it also decides what duplicate() copies.
## Strip Editor Annotations leaves it on variables.

class EaStats extends Resource:
	@export var ea_points : int = 1
	@export_storage var ea_stored : int = 2
	@export_range(0, 100) var ea_ranged : int = 3

class EaNode extends Node:
	@export var ea_node_points : int = 1
	@export_range(0, 100) var ea_node_ranged : int = 2

func run_case() -> String:
	var stats := EaStats.new()
	stats.ea_points = 50
	stats.ea_stored = 60
	stats.ea_ranged = 70
	var stats_copy : EaStats = stats.duplicate()
	if stats_copy.ea_points != 50 or stats_copy.ea_stored != 60 or stats_copy.ea_ranged != 70:
		return "copy of a resource: %d %d %d" % [stats_copy.ea_points, stats_copy.ea_stored, stats_copy.ea_ranged]

	var node := EaNode.new()
	node.ea_node_points = 9
	node.ea_node_ranged = 8
	var node_copy : EaNode = node.duplicate()
	var result : String = "ok"
	if node_copy.ea_node_points != 9 or node_copy.ea_node_ranged != 8:
		result = "copy of a node: %d %d" % [node_copy.ea_node_points, node_copy.ea_node_ranged]
	node.free()
	node_copy.free()
	return result
