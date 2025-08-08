extends Weapon
class_name WeaponSniper

@onready var red_dot := $RedDotContainer

func _physics_process(delta: float) -> void:
	super(delta)
	red_dot.visible = reload_t <= 0.2
	
func shoot() -> void:
	reload_t = fire_rate

	ammo -= 1
	if player:
		var projectile := preload("res://game/projectiles/bullet.tscn").instantiate()
		projectile.look_at_from_position(Vector3.ZERO, -aim_dir, Vector3.UP)
		player.cam.shake_rumble(0.3, 0.1, 16.0)
		player.cam.shake_shock(0.1, 0.5)
		projectile.track_in_event_store = true
		projectile.position = player.cam.global_position
		projectile.speed = 200.0
		projectile.damage = 100
		Main.instance.add_child(projectile)
		#projectile.collision_mask = 1 + 4
	else:
		var projectile := preload("res://game/projectiles/bullet_enemy.tscn").instantiate()
		projectile.enemy = enemy
		projectile.look_at_from_position(Vector3.ZERO, -aim_dir, Vector3.UP)
		#projectile.collision_mask = 1 + 2
		projectile.position = global_position + Vector3.UP * 0.1
		projectile.speed = 200.0
	
		Main.instance.add_child(projectile)

	%AudioShoot.play()
	

func _process(delta: float) -> void:
	red_dot.global_transform.basis.z = lerp(red_dot.global_transform.basis.z, aim_dir, delta * 20.0)
	
