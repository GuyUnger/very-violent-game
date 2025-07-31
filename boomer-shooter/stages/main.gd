class_name Main
extends Node3D

static var instance

var source_id := 1

func _ready() -> void:
	instance = self
	EventStore.register_source(source_id, self)

static var player: Player
