extends StaticBody3D

@export var enabled: bool = false:
	get:
		return enabled
	set(value):
		enabled = value
		


func melee() -> void:
	enabled = true
