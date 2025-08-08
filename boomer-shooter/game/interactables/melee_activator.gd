class_name MeleeActivator
extends Node3DEventRegistered

var noise := FastNoiseLite.new()
var noise_time := randf()*1000.0

signal activated

@export var enabled: bool = false:
	get:
		return enabled
	set(value):
		if value:
			%AudioHit.play()
			%Light.show()
			%Light2.hide()
		if enabled == value:
			return
		enabled = value
		%Activated.visible = value
		$Button/MeshInstance3D.visible = !value
		if value:
			activated.emit()
			%AudioActivate.play()


func shoot_activate() -> void:
	activate()

func melee() -> void:
	activate()

func activate() -> void:
	enabled = true
	EventStore.push_event(EventStoreCommandSet.new(source_id, "enabled", enabled))


func _process(delta: float) -> void:
	noise_time += delta
	if enabled:
		$Button.rotation.x = rotate_toward($Button.rotation.x, 0.0, delta*10.0)
	else:
		$Button.rotation.x = noise.get_noise_1d(noise_time*100.0)
