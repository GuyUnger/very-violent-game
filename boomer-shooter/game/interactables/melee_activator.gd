class_name MeleeActivator
extends Node3DEventRegistered

signal activated

@export var enabled: bool = false:
	get:
		return enabled
	set(value):
		if value:
			%AudioHit.play()
		if enabled == value:
			return
		enabled = value
		%Activated.visible = value
		if value:
			activated.emit()
			%AudioActivate.play()


func shoot_activate() -> void:
	enabled = true
	EventStore.push_event(EventStoreCommandSet.new(source_id, "enabled", enabled))

func melee() -> void:
	enabled = true
	EventStore.push_event(EventStoreCommandSet.new(source_id, "enabled", enabled))