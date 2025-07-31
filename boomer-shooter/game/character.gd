class_name Character
extends CharacterBody3D

const GRAVITY = 48.0

var max_health: int = 32
var health: int = max_health
var aim_dir: Vector3


# Getter/Setter Utils
var center_pos: Vector3:
	get:
		return get_center_pos()

var pos_hor: Vector2:
	get:
		return Vector2(position.x, position.z)
	set(value):
		position.x = value.x
		position.z = value.y

var vel_hor: Vector2:
	get:
		return Vector2(velocity.x, velocity.z)
	set(value):
		velocity.x = value.x
		velocity.z = value.y


func hit(from) -> void:
	health -= from.damage
	if health <= 0:
		die()


func die() -> void:
	hide()


func get_center_pos() -> Vector3:
	return global_position + Vector3.UP * 0.8
