class_name Player
extends Character

signal jumped
signal damaged(amount: float)

const WALK_SPEED = 4.0
const SPRINT_SPEED = 12.0
const CROUCH_SPEED = 1.0
const MOVE_ACCEL = 6.0
const MOVE_DECEL = 13.0
const AIR_ACCEL = 5.0
const AIR_DECEL = 1.0
const JUMP_STRENGTH = 12.0


# References
@onready var cam: Cam = %Cam
@onready var model: Node3D = %Model
@onready var aim_indicator: Crosshair = %Crosshair
@onready var fps_weapon: Node3D = %FpsWeapon
@onready var body_collision_shape: CollisionShape3D = $CollisionShape3D
@onready var ray_down = $RayDown

# Camera
var look_angle: Vector2
var cam_pos: Vector3
var floor_pos: Vector3
var height := 0.0

# Jumping
var allow_jump: bool = true
var allow_jump_release: bool = false
var since_jump_pressed: float = 999.0
var since_on_floor: float = 0.0
var allow_jump_vel_boost: bool = false

var allow_walljump: bool = false

# Shooting

var input_direction: Vector2
var aim_point: Vector3
var look_angle_prev: Vector2
var look_vel: Vector2 = Vector2.ZERO

var since_secondary_pressed: float = 999.0
var melee_reload_t: float = 0.0

var model_position: Vector3 = Vector3.ZERO
var last_camera_rotation: Vector3 = Vector3.ZERO
var velocity_prev: Vector3 = Vector3.ZERO

# Audio
var walk_cycle: float = 0.0
var walk_cycle_next_step: int = 0

var weapon:Weapon

@export var starting_weapon:PackedScene
@export var close_on_escape = false
@export_range(0.0, 10.0, 0.1) var damage_cooldown := 1.0
## When disabled, the player's body stops colliding but movement and gravity continue.
@export var physics_enabled := true:
	set = set_physics_enabled
@export var mounted := false:
	set = set_mounted
@export var mounted_x_bounds := Vector2(-45.0, 45.0)
@export var mounted_y_bounds := Vector2(-30.0, 30.0)

@export_category("Collision")
@export_range(0.1, 4.0, 0.05, "or_greater") var standing_height := 1.5
@export_range(0.1, 4.0, 0.05, "or_greater") var crouching_height := 0.5

var dead: bool = false
var mounted_look_center := Vector2.ZERO

var invincible_t: float = 0.0

var last_hit_enemy
var crouching := false
var climbing := false
var standing_collision_height := 0.0
var standing_collision_position_y := 0.0
var crouching_collision_height := 0.0
var crouching_collision_position_y := 0.0

#region Initialization

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	_apply_physics_enabled()

	if starting_weapon:
		var starting_weapon_instance := starting_weapon.instantiate()
		if starting_weapon_instance is Weapon:
			_equip_weapon(starting_weapon_instance)
		else:
			push_warning("Player starting_weapon scene must have a Weapon root node.")
			starting_weapon_instance.queue_free()
	
	Main.player = self
	
	await get_tree().process_frame
	
	look_angle.x = -rotation.y - PI * 0.5
	if mounted:
		_capture_mounted_look_center()
	
	cam.reparent(get_parent())

#endregion

#region Processing

var last_camp_up_ := 0.0

func _process(delta: float) -> void:
	if dead:
		if last_hit_enemy:
			var looking_at_transform = cam.global_transform
			looking_at_transform = looking_at_transform.looking_at(last_hit_enemy.global_position + Vector3.UP * 1.0, Vector3.UP)
			cam.global_transform = cam.global_transform.interpolate_with(looking_at_transform, delta * 5.0)
			#cam.look_at(last_hit_enemy.global_position + Vector3.UP * 1.5, Vector3.UP)
		return
	
	if invincible_t > 0.0:
		invincible_t -= delta
	%Crosshair.visible = weapon != null
	
	#if Input.is_action_just_pressed("toggle_view"):

	#region Camera
	# Apply look_vel (controller input)
	look_angle += look_vel * 5.0 * delta
	
	# Clamp look angle
	if mounted:
		_clamp_mounted_look()
	look_angle.x = wrapf(look_angle.x, 0.0, TAU)
	look_angle.y = clamp(look_angle.y, -PI * 0.45, PI * 0.35)
	
	# Look Horizontal 
	cam.rotation.y = -look_angle.x - PI * 0.5
	
	# Look Vertical
	cam.rotation.x = ease(absf(look_angle.y), -1.2) * sign(look_angle.y) - 0.2
	cam.rotation.x = look_angle.y
	
	var cam_up := global_position.y


	# Apply cam position
	if is_on_floor_ex():
		floor_pos = global_position
	
	
	var cam_pos_to: Vector3 = global_position
	if is_on_floor_ex():
		cam_pos.y += sin(walk_cycle * PI) * vel_hor.length() * 0.01
		cam_pos_to += transform.basis.z * cos(walk_cycle * PI * 0.5) * vel_hor.length() * 0.01
	cam_pos.x = cam_pos_to.x
	cam_pos.z = cam_pos_to.z
	cam_pos.y = lerp(last_camp_up_, cam_pos_to.y, delta * 30.0)
	cam.global_position = cam_pos
	
	last_camp_up_ = cam_pos.y
	#endregion
	

	process_targets()
	process_target_indicators(delta)



func _physics_process(delta: float) -> void:
	if dead:
		if last_hit_enemy:
			cam.camera.fov = lerp(cam.camera.fov, 60.0, delta * 5.0)
			
		
		else:
			cam.camera.fov = lerp(cam.camera.fov, 120.0, delta * 5.0)
		return
	
	#region Input
	var look_vel_to: Vector2 = Input.get_vector(
			"joy_left", "joy_right",
			"joy_down", "joy_up")
	if look_vel_to.length() < 0.1:
		look_vel = lerp(look_vel, Vector2.ZERO, delta * 20.0)
	else:
		look_vel = lerp(look_vel, look_vel_to * Vector2(1.0, 0.8) * Settings.look_sensitivity, delta * 10.0)
	
	if Input.is_action_just_pressed("jump"):
		since_jump_pressed = 0.0
	else:
		since_jump_pressed += delta
	
	#endregion
	
	#region Movement
	input_direction = Input.get_vector(
			"left", "right",
			"forward", "backward")
	
	if ray_down.is_colliding():
		var collider = ray_down.get_collider()
		if collider.get("climbable"):
			climbing = true
		else:
			climbing = false
	else:
		climbing = false
	
	_process_movement(delta)
	_process_melee(delta)
	
	if is_on_floor_ex():
		if since_on_floor > 0.2:
			_on_land()
		since_on_floor = 0.0
		allow_jump_vel_boost = true
	else:
		since_on_floor += delta
	
	if weapon:
		sway_weapon(delta)
		
		weapon.aim_dir = aim_dir
		if Input.is_action_just_pressed("primary"):
			weapon.trigger_pressed = true
		elif Input.is_action_just_released("primary"):
			weapon.trigger_pressed = false
			
			
		if Input.is_action_just_pressed("throw"):
			throw_weapon()

	# Fall out of world
	if position.y < -20.0:
		die()
		return
	
	look_angle_prev = look_angle
	velocity_prev = velocity
	
	for body in %PickUp.get_overlapping_bodies():
		if not weapon and body is Weapon and body.ammo > 0 and body.since_thrown > 0.2:
			if _equip_weapon(body):
				break
	

func throw_weapon() -> void:
	if not weapon:
		return
	weapon.global_position = global_position + Vector3.UP * 1.5
	weapon.throw(aim_dir * 30.0)
	weapon = null


#endregion

#region Movement

func is_on_floor_ex() -> bool:
	return true

func _process_movement(delta:float) -> void:
	if mounted:
		input_direction = Vector2.ZERO
		velocity = Vector3.ZERO
		return

	# Rotate towards view direction
	if input_direction != Vector2.ZERO:
		rotate_towards_view_direction()
	else:
		rotate_towards_view_direction(delta * 2.0)

	_update_crouch_state(delta)
	
	# Movement
	var move_speed := WALK_SPEED
	if crouching:
		move_speed = CROUCH_SPEED
	elif Input.is_action_pressed("sprint"):
		move_speed = SPRINT_SPEED
	
	var accel: float
	if input_direction == Vector2.ZERO:
		# Decelerate
		accel = MOVE_DECEL if is_on_floor_ex() else AIR_DECEL
	else:
		# Accelerate
		accel = MOVE_ACCEL if is_on_floor_ex() else AIR_ACCEL
	vel_hor_to(input_direction * move_speed, accel * delta)
	
	
	if climbing:
		if crouching:
			position.y = standing_height - 0.3
		else:
			position.y = standing_height + 0.3
	elif crouching:
		position.y = crouching_height
	else:
		position.y = standing_height
		
	
	# Gravity
	#var gravity_scale: float = 1.0
	# absf(velocity.y) < 3.0:
	#	# Hovering at jump peak
	#	gravity_scale = 0.5
	#if velocity.y < 0.2:
	#	gravity_scale *= 1.0 - melee_reload_t
	#velocity.y -= GRAVITY * delta * gravity_scale
	
	
	# Jumping
	#if (	is_jump_just_pressed(0.2) and since_on_floor < 0.1
	#		and allow_jump):
	#	jump()
	#if allow_jump_release and not Input.is_action_pressed("jump"):
	#	# Stop jumping
	#	allow_jump_release = false
	#	if velocity.y > 0.0:
	#		velocity.y *= 0.5
	#if not allow_jump and is_on_floor() and not allow_jump_release:
	#	# Reset jump state
	#	allow_jump = true
	
	# Jump velocity boost
	#process_jump_vel_boost()
	
	# Apply movement
	apply_move_and_slide()
	
	if is_on_floor_ex():
		walk_cycle += delta * vel_hor.length() / maxf(move_speed, 0.001) * 5.0
		
		if walk_cycle > walk_cycle_next_step:
			walk_cycle_next_step += 1
			_on_step(walk_cycle_next_step % 2 == 0)


func _on_land() -> void:
	%AudioLand.play()
	cam.shake_shock(0.2, maxf(0.0, (-velocity_prev.y * 0.2 - 3.0)))
	cam.shake_land(0.5, minf(absf(velocity_prev.y) / 20.0, 2.0))


func _on_step(left: bool) -> void:
	%AudioStep.pitch_scale = 0.4 + (0.1 if left else -0.1)
	%AudioStep.play()


func apply_move_and_slide() -> void:
	move_and_slide()
	for i in get_slide_collision_count():
		var collision := get_slide_collision(i)
		if not collision:
			continue

		var normal: Vector3 = collision.get_normal()
		if melee_reload_t > 0.7 and allow_walljump and absf(normal.y) < 0.1:
			#velocity = (velocity_prev.bounce(normal) * Vector3(1.0, 0.0, 1.0)).normalized() * SPRINT_SPEED * 2.0
			velocity = normal * SPRINT_SPEED * 2.0
			allow_walljump = false
			velocity.y = JUMP_STRENGTH * 1.5
			%AudioWallbounce.play()

		_try_break_wall_from_sprint(collision)


func vel_hor_to(to:Vector2, t:float = 1.0) -> void:
	var velocity_local_space: Vector3 = (
			-basis.x * to.y
			+basis.z * to.x)
	velocity.x = lerp(velocity.x, velocity_local_space.x, t)
	velocity.z = lerp(velocity.z, velocity_local_space.z, t)


func jump() -> void:
	velocity.y = JUMP_STRENGTH
	allow_jump_release = true
	allow_jump = false
	%AudioJump.play()
	$AudioJump.play()
	jumped.emit()
	cam.shake_land(0.4, 0.5)


func _try_break_wall_from_sprint(collision: KinematicCollision3D) -> void:
	if not Input.is_action_pressed("sprint"):
		return

	var collider := collision.get_collider()
	if not collider or not collider.has_method("try_break_from_sprint_impact"):
		return

	var impact_direction := Vector3(velocity_prev.x, 0.0, velocity_prev.z)
	if impact_direction.length_squared() < 0.01 and input_direction != Vector2.ZERO:
		impact_direction = (-basis.x * input_direction.y + basis.z * input_direction.x)
		impact_direction.y = 0.0
	if impact_direction.length_squared() < 0.01:
		impact_direction = -cam.global_basis.z
		impact_direction.y = 0.0
	impact_direction = impact_direction.normalized()

	var impact_normal := collision.get_normal()
	if impact_normal.dot(impact_direction) > -0.5:
		return

	if collider.try_break_from_sprint_impact():
		cam.shake_shock(0.25, 0.8)


func rotate_towards_view_direction(t: float = 1.0) -> void:
	rotation.y = lerp_angle(rotation.y, -look_angle.x,  t)


func set_mounted(value: bool) -> void:
	if mounted == value:
		return

	mounted = value
	if mounted:
		_capture_mounted_look_center()
		input_direction = Vector2.ZERO
		look_vel = Vector2.ZERO
		velocity = Vector3.ZERO


func set_physics_enabled(value: bool) -> void:
	physics_enabled = value
	if is_inside_tree():
		_apply_physics_enabled()


func _apply_physics_enabled() -> void:
	for child in get_children():
		if child is CollisionShape3D:
			child.set_deferred("disabled", not physics_enabled)


func _capture_mounted_look_center() -> void:
	mounted_look_center = look_angle


func _clamp_mounted_look() -> void:
	var x_min := deg_to_rad(minf(mounted_x_bounds.x, mounted_x_bounds.y))
	var x_max := deg_to_rad(maxf(mounted_x_bounds.x, mounted_x_bounds.y))
	var y_min := deg_to_rad(minf(mounted_y_bounds.x, mounted_y_bounds.y))
	var y_max := deg_to_rad(maxf(mounted_y_bounds.x, mounted_y_bounds.y))

	var x_offset := angle_difference(mounted_look_center.x, look_angle.x)
	var y_offset := look_angle.y - mounted_look_center.y
	look_angle.x = mounted_look_center.x + clampf(x_offset, x_min, x_max)
	look_angle.y = mounted_look_center.y + clampf(y_offset, y_min, y_max)


func _update_crouch_state(delta: float) -> void:
	var wants_to_crouch := Input.is_action_pressed("crouch")
	if wants_to_crouch:
		crouching = true
	#elif _can_stand_up():
	else:
		crouching = false



func _can_stand_up() -> bool:
	if not crouching:
		return true
	return not test_move(global_transform, Vector3.UP * 0.6)


func get_center_pos() -> Vector3:
	return cam.global_position


func process_jump_vel_boost() -> void:
	var move_speed := WALK_SPEED
	if crouching:
		move_speed = CROUCH_SPEED
	elif Input.is_action_pressed("sprint"):
		move_speed = SPRINT_SPEED

	if (	allow_jump_vel_boost
			and not is_on_floor_ex()
			and is_jump_just_pressed()
			and input_direction != Vector2.ZERO
			and vel_hor.length() > move_speed * 0.2):
		allow_jump_vel_boost = false
		vel_hor_to(input_direction * move_speed, 0.5)

#endregion

#region Targetting

func process_targets() -> void:
	aim_dir = -cam.global_basis.z
	aim_point = cam.global_position + aim_dir * 100.0


func process_target_indicators(delta: float) -> void:
	var aim_pos: Vector2 = cam.camera.unproject_position(aim_point)
	aim_indicator.process(aim_pos, delta, null)

#endregion

#region Melee

func _process_melee(delta) -> void:
	if Input.is_action_just_pressed("primary"):
		since_secondary_pressed = 0.0
	else:
		since_secondary_pressed += delta
	
	melee_reload_t = move_toward(melee_reload_t, 0.0, delta / 0.6)
	
	if since_secondary_pressed < 0.2 and melee_reload_t <= 0.0 and weapon and weapon is WeaponKatana:
		vel_hor *= 3.5
		invincible_t = 0.3
		allow_walljump = true
		melee_reload_t = 1.0
		since_secondary_pressed = 999.0
		%AudioMelee.play()
		%MeleeAttack.show()
		
		%MeleeAttack.rotation.y = 0.0
		var tween = create_tween()
		tween.tween_property(%MeleeAttack, "rotation:y", -TAU, 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		
		for i in 4:
			await get_tree().create_timer(0.05).timeout
			if not get_tree():
				return
			
			for body in %AreaMelee.get_overlapping_bodies():
				if "melee" in body:
					body.melee()
				elif "melee" in body.get_parent():
					body.get_parent().melee()
		
		%MeleeAttack.hide()

#endregion

#region Input

func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		# Toggle fullscreen
		if Input.is_action_just_pressed("fullscreen"):
			var is_fullscreen: bool = \
					DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
			
			if is_fullscreen:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			else:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		
		if event.is_action_pressed("exit"):
			if close_on_escape:
				get_tree().quit()
			else:
				if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
					Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	if event is InputEventMouseMotion:
		var mouse_speed: float = 0.1 * Settings.look_sensitivity
		var mouse_motion: InputEventMouseMotion = event
		look_angle.x += mouse_motion.relative.x * mouse_speed / TAU
		look_angle.y -= mouse_motion.relative.y * mouse_speed / TAU * 0.7


func is_jump_just_pressed(grace: float = 0.1) -> bool:
	return since_jump_pressed < grace


#endregion

func sway_weapon(delta):
	fps_weapon.position.y = sin(walk_cycle*3.2)*0.012
	fps_weapon.position.z = sin(0.5+walk_cycle*3.2)*0.012
	fps_weapon.position.x = lerp(fps_weapon.position.x, angle_difference(cam.rotation.y, last_camera_rotation.y)*0.5, delta*20.0)
	fps_weapon.rotation.z = fps_weapon.position.x*3.0
	fps_weapon.rotation.y = -fps_weapon.position.x*3.0
	fps_weapon.rotation.x = lerp(fps_weapon.rotation.x, angle_difference(cam.rotation.x, last_camera_rotation.x)*2.5, delta*20.0)
	last_camera_rotation = cam.rotation

static var dead_sound: int = 0

static var DEAD_SOUNDS: Array = [
	preload("res://content/player/die 01.wav"),
]

func die(_normal := Vector3.ZERO, _hit_shape: CollisionShape3D = null) -> void:
	if dead:
		return
	dead = true
	Main.hud.hide_gameplay_ui()
	%Crosshair.hide()
	
	if DEAD_SOUNDS.size() == 1:
		dead_sound = 0
	elif DEAD_SOUNDS.size() > 1:
		var previous_dead_sound := dead_sound
		while previous_dead_sound == dead_sound:
			dead_sound = randi() % DEAD_SOUNDS.size()

	if not DEAD_SOUNDS.is_empty():
		$AudioDie.stream = DEAD_SOUNDS[dead_sound]
		$AudioDie.play()
	throw_weapon()
	
	await get_tree().create_timer(1.0).timeout

	if (
		is_instance_valid(MapEditor.instance)
		and MapEditor.instance.gameplay_instance
	):
		MapEditor.instance.restart_playtest(Color.RED)
	else:
		Transition.reload_current_scene(Color.RED)


func _pick_up_body_entered(body: Node3D) -> void:
	if body is Weapon and body.ammo > 0 and body.since_thrown > 0.2:
		_equip_weapon(body)


func _equip_weapon(new_weapon: Weapon) -> bool:
	if weapon or not is_instance_valid(new_weapon):
		return false

	weapon = new_weapon
	if new_weapon.is_inside_tree():
		new_weapon.reparent(fps_weapon)
	else:
		fps_weapon.add_child(new_weapon)
	new_weapon.pickup(self)
	return true
		


func animate_crosshair() -> void:
	%Crosshair.since_hit = 0.0
	$AudioHit.play()


func hit(damage: float, normal := Vector3.ZERO, hit_shape: CollisionShape3D = null) -> void:
	if invincible_t > 0.0:
		return
	invincible_t = damage_cooldown
	damaged.emit(damage)
	super(damage, normal, hit_shape)
