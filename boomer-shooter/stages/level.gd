extends Node3D

@export var time: float = 10.0

func _process(delta: float) -> void:
	time -= delta
	if time < 0:
		Main.player.die()
