extends Node3D
class_name Weapon

var target_range: float = 20.0
var reload_t: float = 0.0
var since_primary_pressed: float = 999.0

var is_auto: bool = true

var player: Player


func process(delta: float) -> void:
	if reload_t > 0.0:
		reload_t -= delta
	
	if Input.is_action_just_pressed("primary"):
		since_primary_pressed = 0.0
	else:
		since_primary_pressed += delta
	
	if is_auto:
		if Input.is_action_pressed("primary") and reload_t <= 0.0:
			shoot()
	else:
		if since_primary_pressed < 0.2 and reload_t <= 0.0:
			shoot()
			since_primary_pressed = 999.0


func shoot() -> void:
	#$AudioStreamPlayer3D.pitch_scale = randf_range(1.0, 1.2)
	$AudioStreamPlayer3D.play()
	
	
	reload_t = 0.1
	player.cam.shake_rumble(0.3, 0.1, 16.0)
	player.cam.shake_shock(0.1, 0.5)
	
	var projectile := preload("res://game/projectiles/bullet.tscn").instantiate()
	projectile.look_at_from_position(Vector3.ZERO, -player.aim_dir, Vector3.UP)
	projectile.position = player.model_position + Vector3.UP * 1.4
	
	Main.instance.add_child(projectile)
