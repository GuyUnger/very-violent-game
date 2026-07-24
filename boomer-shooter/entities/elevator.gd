@tool
extends Node3D

@export var open:bool :
	set(v):
		open = v
		
		if open:
			open_()
		else:
			close_()
		

var tween_:Tween

func _ready() -> void:
	$Area3D.body_entered.connect(_player_entered)
	
	
func _player_entered(player) -> void:
	open = false


func open_() -> void:
	if tween_:
		tween_.kill()
		
	tween_ = create_tween()
	tween_.set_parallel()
	tween_.tween_property($LeftDoor, "position:x", -1.0, 1.0)
	tween_.tween_property($RightDoor, "position:x", 1.0, 1.0)


func close_() -> void:
	if tween_:
		tween_.kill()
		
	tween_ = create_tween()
	tween_.set_parallel()
	tween_.tween_property($LeftDoor, "position:x", -0.75 / 2.0, 1.0)
	tween_.tween_property($RightDoor, "position:x", 0.75 / 2.0, 1.0)
