extends Node3D

var time: float = 10.0

func _process(delta: float) -> void:
	time -= delta
	if time < 0:
		Main.player.die()