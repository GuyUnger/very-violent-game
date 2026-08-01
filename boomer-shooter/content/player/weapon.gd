extends CharacterBody3D
class_name Weapon

signal released_by_holder

enum HoldPose {
	PISTOL,
	RIFLE
}

@export var fire_rate := 0.0
@export var auto := false
@export var hold_pose:HoldPose
@export var recoil := 0.0
@export var penetration_power := 0.0

var target_range: float = 20.0
var reload_t: float = 0.0
var since_primary_pressed: float = 999.0
var aim_dir := Vector3.ZERO
var throwing_velocity := Vector3.ZERO
var player: Player
var enemy
var trigger_pressed:bool :
	set = set_trigger_pressed

@export var ammo: int = 40
@onready var max_ammo = ammo

var total_recoil: float = 0.0
var since_thrown: float = 99.0

@export var pickup_sounds: Array[AudioStream]
var pickup_sounds_b: Array[AudioStream] = [
	preload("res://content/weapons/pickup_sfx/pickup_default 01.wav"),
	preload("res://content/weapons/pickup_sfx/pickup_default 02.wav"),
	preload("res://content/weapons/pickup_sfx/pickup_default 04.wav"),
]

@export var damage_scale: int = 1
@export_range(1, 100, 1) var enemy_damage: int = 1


func set_trigger_pressed(value:bool) -> void:
	if value != trigger_pressed:
		if value:
			_trigger_just_pressed()
	trigger_pressed = value


func _trigger_just_pressed() -> void:
	since_primary_pressed = 0.0


func _physics_process(delta: float) -> void:
	total_recoil = max(0.0, total_recoil - delta)
	
	if player and player.dead:
		return

	if velocity != Vector3.ZERO:
		since_thrown += delta
		velocity.y -= 9.8 * delta
		move_and_slide()
		rotation.y += delta * 10.0
		if is_on_floor():
			velocity -= velocity * 4.0 * delta
		return
	
	if reload_t > 0.0:
		reload_t -= delta

	since_primary_pressed += delta
	
	if auto and ammo > 0:
		if trigger_pressed and reload_t <= 0.0:
			shoot()
			if ammo <= 0:
				if is_instance_valid(player):
					player.throw_weapon()
	else:
		if since_primary_pressed < 0.2 and reload_t <= 0.0:
			shoot()
			if ammo <= 0:
				if is_instance_valid(player):
					player.throw_weapon()
			since_primary_pressed = 999.0
	
	if has_node("%Hand"):
		%Hand.visible = player != null

func shoot() -> void:
	ammo -= 1
	reload_t = fire_rate
	if has_node("Animations"):
		$Animations.shoot()
	if has_node("Muzzleflash"):
		$Muzzleflash.shoot()
	
	var r = Vector3(
		randf_range(-total_recoil, total_recoil), 
		randf_range(-total_recoil, total_recoil) * 0.4,
		randf_range(-total_recoil, total_recoil)) * 0.5

	if player:
		var projectile := preload("res://content/projectiles/bullet.tscn").instantiate()
		projectile.look_at_from_position(Vector3.ZERO, -aim_dir + r, Vector3.UP)
		
		player.cam.shake_rumble(0.3, 0.3, 16.0)
		player.cam.shake_shock(0.2, 0.5)
		projectile.position = player.cam.global_position
		projectile.damage *= damage_scale
		projectile.penetration_power = penetration_power
		Main.instance.add_child(projectile)
		#projectile.collision_mask = 1 + 4
	else:
		var projectile := preload("res://content/projectiles/bullet.tscn").instantiate()
		projectile.enemy = enemy
		projectile.damage = enemy_damage
		projectile.look_at_from_position(Vector3.ZERO, -aim_dir + r, Vector3.UP)
		projectile.collision_mask = 1 + 2
		projectile.position = global_position + Vector3.UP * 0.1
		projectile.penetration_power = penetration_power
	
		Main.instance.add_child(projectile)
	
	if player:
		%AudioShoot.play()
	else:
		%AudioShootNPC.play()
		
	total_recoil = recoil

func throw(force:Vector3) -> void:
	var had_holder := player != null or enemy != null
	trigger_pressed = false
	player = null
	enemy = null
	since_thrown = 0.0
	
	
	reparent(Main.instance)
	
	collision_mask = 1
	velocity = force

	collision_layer = 64
	await get_tree().create_timer(0.2).timeout
	
	if ammo > 0:
		$PickupGlow.show()

	if had_holder:
		released_by_holder.emit()
	
	


func activate_world_pickup() -> void:
	trigger_pressed = false
	player = null
	enemy = null
	velocity = Vector3.ZERO
	since_thrown = 99.0
	collision_mask = 1
	collision_layer = 64
	if ammo > 0:
		$PickupGlow.show()


func pickup(p_player: Player) -> void:
	hide_glow()
	player = p_player
	enemy = null
	velocity = Vector3.ZERO
	collision_mask = 0
	collision_layer = 0
	await Main.instance.get_tree().process_frame
	position = Vector3.ZERO
	rotation = Vector3.ZERO

func hide_glow() -> void:
	$PickupGlow.hide()
