class_name DoorSlideWall
extends Node3DEventRegistered


var _animation_tween: Tween
var activated: bool:
	set(value):
		if value == activated:
			return
		activated = value
		await get_tree().create_timer(0.2).timeout
		if _animation_tween:
			_animation_tween.kill()
		_animation_tween = create_tween()
		_animation_tween.tween_property($Collider, "position:y", -3.0 if value else 0.0, 1.5)
		%AudioMove.play()
		await _animation_tween.finished
		%AudioMove.stop()
		%AudioStop.play()
		


func activate() -> void:
	if not activated:
		activated = true
		EventStore.push_event(EventStoreCommandSet.new(EventStore.unique_source_id(self), "activated", true))
