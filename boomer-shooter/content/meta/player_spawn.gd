extends Node3D

func _ready() -> void:
	if Main.player:
		Main.player.global_transform = global_transform
