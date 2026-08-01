class_name NPCHeardTargetMarker
extends Node3D

var elapsed := 0.0


func _process(delta: float) -> void:
	elapsed += delta
	$Visual.rotation.y += delta * 2.5
	var pulse := 1.0 + sin(elapsed * 6.0) * 0.12
	$Visual.scale = Vector3.ONE * pulse


func get_center_pos() -> Vector3:
	return global_position + Vector3.UP
