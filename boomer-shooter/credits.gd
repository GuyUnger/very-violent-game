extends Control

func _ready() -> void:
	$AnimationPlayer.play("new_animation")


func _start_game() -> void:
	get_tree().change_scene_to_file("res://stages/level_roof.tscn")
