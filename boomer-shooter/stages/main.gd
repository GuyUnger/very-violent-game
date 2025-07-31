class_name Main
extends Node3D

var event_store_id := "main"

func _ready() -> void:
	EventStore.register_source(event_store_id, self)


static var player: Player
