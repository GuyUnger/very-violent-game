class_name Main
extends Node3D

static var instance

var source_id := 1

var time: float = 20.0

func _init() -> void:
	instance = self
	

func _ready() -> void:
	EventStore.register_source(source_id, self)

static var player: Player

func _process(delta: float) -> void:
	if time > 0:
		time -= delta
		if time <= 0:
			player.die()
		
