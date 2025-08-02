extends CharacterBody3D
class_name Weapon

enum HoldPose {
	PISTOL,
	RIFLE
}

@export var fire_rate := 0.0
@export var auto := false
@export var hold_pose:HoldPose

var target_range: float = 20.0
var reload_t: float = 0.0
var since_primary_pressed: float = 999.0
var aim_dir := Vector3.ZERO
var throwing_velocity := Vector3.ZERO
var player: Player
var trigger_pressed:bool :
	set = set_trigger_pressed

@onready var handle: MeshInstance3D = $WorldModel/weapon_smg/SMG/Handle

@export var ammo: int = 40

var since_thrown: float = 99.0

@export var pickup_sounds: Array[AudioStream]
var pickup_sounds_b: Array[AudioStream] = [
	preload("res://game/weapons/pickup_default 01.wav"),
	preload("res://game/weapons/pickup_default 02.wav"),
	preload("res://game/weapons/pickup_default 04.wav"),
]


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
	else:
		if since_primary_pressed < 0.2 and reload_t <= 0.0:
			if ammo > 0:
				shoot()
			elif player:
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
	since_thrown = 0.0
	
	reparent(Main.instance)
	
	collision_mask = 1
	velocity = force

	#await get_tree().create_timer(0.2).timeout
	collision_layer = 8
	

func pickup(p_player: Player) -> void:
	if pickup_sounds.size() == 0:
		%AudioPickup.stream = pickup_sounds_b.pick_random()
	else:
		%AudioPickup.stream = pickup_sounds.pick_random()
	%AudioPickup.play()
	%AudioPickup.pitch_scale = 1.1
	
	player = p_player
	velocity = Vector3.ZERO
	collision_mask = 0
	collision_layer = 0
#	await get_tree().process_frame
	position = Vector3.ZERO
	rotation = Vector3.ZERO
