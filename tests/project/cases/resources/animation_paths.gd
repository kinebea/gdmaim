extends Node

## The methods and properties an animation names are renamed along with the script, also in an
## animation or a library saved as a file of its own, and in a SceneReplicationConfig.
## None of these files has a script or an exported variable.

func played(scene_path : String) -> String:
	var actor : Node = load(scene_path).instantiate()
	add_child(actor)
	var player : AnimationPlayer = actor.get_node("AnimationPlayer")
	player.play("attack")
	player.advance(0.6)
	await get_tree().process_frame
	await get_tree().process_frame
	var result : String = "hits=%d health=%d" % [actor.hits_zq, actor.health_zq]
	actor.queue_free()
	return result

func run_case() -> String:
	var expected : String = "hits=1 health=50"
	var embedded : String = await played("res://cases/resources/data/animation_embedded.tscn")
	if embedded != expected:
		return "animation inside the scene: " + embedded
	var file : String = await played("res://cases/resources/data/animation_file.tscn")
	if file != expected:
		return "animation in a file of its own: " + file
	var library : String = await played("res://cases/resources/data/animation_library.tscn")
	if library != expected:
		return "animation library in a file of its own: " + library

	var actor : Node = load("res://cases/resources/data/replication.tscn").instantiate()
	var path : NodePath = actor.get_node("Sync").replication_config.get_properties()[0]
	var value = actor.get(path.get_concatenated_subnames())
	actor.free()
	if value != 1:
		return "replicated property %s is not one of the node" % path
	return "ok"
