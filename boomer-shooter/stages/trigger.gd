extends Node

func _ready() -> void:
	get_parent().all_enemies_killed.connect(_all_enemies_killed)
	

func _all_enemies_killed() -> void:
	var t := create_tween()
	t.tween_interval(3.0)
	t.tween_property(%Desk, "position:y", -2.0, 1.0)
