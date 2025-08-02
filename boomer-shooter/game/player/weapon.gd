extends CharacterBody3D
class_name Weapon

@export var fire_rate := 0.0
@export var auto := false

var target_range: float = 20.0
var reload_t: float = 0.0
var since_primary_pressed: float = 999.0
var aim_dir := Vector3.ZERO
var throwing_velocity := Vector3.ZERO
var player: Player
var trigger_pressed:bool :
	set = set_trigger_pressed

@onready var handle: MeshInstance3D = $WorldModel/weapon_smg/SMG/Handle


func set_trigger_pressed(value:bool) -> void:
	if value != trigger_pressed:
		if value:
			_trigger_just_pressed()
	trigger_pressed = value


func _trigger_just_pressed() -> void:
	since_primary_pressed = 0.0


func _physics_process(delta: float) -> void:
	if player and player.dead:
		return
	if velocity != Vector3.ZERO:
		velocity.y -= 9.8 * delta
		move_and_slide()
		rotation.y += delta * 10.0
		
		return
	
	if reload_t > 0.0:
		reload_t -= delta

	since_primary_pressed += delta
	
	if auto:
		if trigger_pressed and reload_t <= 0.0:
			shoot()
	else:
		if since_primary_pressed < 0.2 and reload_t <= 0.0:
			shoot()
			since_primary_pressed = 999.0


func shoot() -> void:
	reload_t = fire_rate
	$Animations.shoot()
	$Muzzleflash.shoot()
	
	if player:
		var projectile := preload("res://game/projectiles/bullet.tscn").instantiate()
		projectile.look_at_from_position(Vector3.ZERO, -aim_dir, Vector3.UP)
		
		player.cam.shake_rumble(0.3, 0.3, 16.0)
		player.cam.shake_shock(0.2, 0.5)
		projectile.track_in_event_store = true
		projectile.position = player.cam.global_position
		Main.instance.add_child(projectile)
		#projectile.collision_mask = 1 + 4
	else:
		var projectile := preload("res://game/projectiles/bullet_enemy.tscn").instantiate()
		projectile.look_at_from_position(Vector3.ZERO, -aim_dir, Vector3.UP)
		#projectile.collision_mask = 1 + 2
		projectile.position = global_position + Vector3.UP * 0.1
	
		Main.instance.add_child(projectile)
	
	if player:
		%AudioShoot.play()
	else:
		%AudioShootNPC.play()
	
func throw(force:Vector3) -> void:
	trigger_pressed = false
	player = null
	
	reparent(Main.instance)
	
	collision_mask = 1
	velocity = force

	await get_tree().create_timer(0.2).timeout
	collision_layer = 8
	
