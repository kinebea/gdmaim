extends Node

## Only value and bezier tracks name a property. The path of a position track ends in the name
## of a bone, which here is that of a class of data/dictionary_actor.gd.

func run_case() -> String:
	var rig : Node = load("res://cases/resources/data/skeleton.tscn").instantiate()
	add_child(rig)
	var player : AnimationPlayer = rig.get_node("AnimationPlayer")
	player.play("swing")
	player.advance(0.5)
	await get_tree().process_frame
	var skeleton : Skeleton3D = rig.get_node("Skeleton3D")
	var position : Vector3 = skeleton.get_bone_pose_position(0)
	var track : NodePath = player.get_animation("swing").track_get_path(0)
	rig.queue_free()
	if !position.is_equal_approx(Vector3(1, 2, 3)):
		return "the bone did not move, the track leads to %s" % track
	return "ok"
