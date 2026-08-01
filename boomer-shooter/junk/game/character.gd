class_name Character
extends CharacterBody3D

const GRAVITY = 40.0

@export var max_health := 2.0
@export var health := 2.0

var aim_dir: Vector3

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


func hit(damage: float, normal := Vector3.ZERO, hit_shape: CollisionShape3D = null) -> void:
	health -= damage
	if health <= 0:
		die(normal, hit_shape)


func hit_with_damage_event(event: DamageEvent) -> void:
	hit(event.get_damage(), event.hit_normal, event.hit_shape)


func die(_normal := Vector3.ZERO, _hit_shape: CollisionShape3D = null) -> void:
	hide()


func get_center_pos() -> Vector3:
	return global_position + Vector3.UP * 1.4
