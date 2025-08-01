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

var count_down_played: bool = false
func _process(delta: float) -> void:
	if time > 0:
		if time < 5.0 and not count_down_played:
			%AudioCountDown.play()
			count_down_played = true
		time -= delta
		if time <= 0:
			player.die()
		
