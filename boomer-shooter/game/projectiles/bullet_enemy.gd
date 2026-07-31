extends Node3D

var direction: Vector3
var speed: float = 25.0
var knock_back := 0.0

var damage: int = 5

var enemy


var dead: bool = false:
	set(v):
		dead = v
		if dead:
			queue_free()


func _ready() -> void:
	direction = global_transform.basis.z.normalized()


func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta


func _on_area_3d_body_entered(body:Node3D) -> void:
	if dead:
		return
	dead = true
	if "hit" in body and "dead" in body and not body.dead:
		body.hit(damage)
		if enemy and "last_hit_enemy" in body:
			body.last_hit_enemy = enemy
	#queue_free()
