class_name Node3DEventRegistered
extends Node3D


@onready var source_id = EventStore.unique_source_id(self)


func _ready() -> void:
	EventStore.register_source(source_id, self)
