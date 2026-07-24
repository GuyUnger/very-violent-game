extends Node

@export var node:Prop
@export var door:Node3D
@export var wire:Node3D
@export var blocker:Node3D

func _ready() -> void:
	if node:
		node.died.connect(_switch)

func _switch() -> void:
	door.open = true
	wire.trigger()
	blocker.queue_free()
