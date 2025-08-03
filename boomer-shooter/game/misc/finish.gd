extends Area3D

@export var next_level: String

var entered: bool = false

func _on_body_entered(body:Node3D) -> void:
	if entered:
		return
	entered = true
	
	get_tree().paused = true
	await Transition.close()
	get_tree().change_scene_to_file(next_level)
	Transition.open()
	