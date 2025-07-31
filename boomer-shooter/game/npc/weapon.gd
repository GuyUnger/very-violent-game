extends Node3D

var target_range: float = 20.0
var reload_t: float = 0.0
var since_primary_pressed: float = 999.0
var is_auto: bool = true
var trigger_down:bool
var aim_dir := Vector3.ZERO

func _process(delta: float) -> void:
	if reload_t > 0.0:
		reload_t -= delta
	
	#if trigger_down:
	#	since_primary_pressed = 0.0
	#else:
	#	since_primary_pressed += delta
	
	if is_auto:
		if trigger_down and reload_t <= 0.0:
			shoot()
	else:
		if since_primary_pressed < 0.2 and reload_t <= 0.0:
			shoot()
			since_primary_pressed = 999.0


func shoot() -> void:
	reload_t = 0.5
	
	var projectile := preload("res://game/projectiles/bullet.tscn").instantiate()
	projectile.look_at_from_position(Vector3.ZERO, -aim_dir, Vector3.UP)
	projectile.position = global_position
	
	Main.instance.add_child(projectile)
