class_name Player
extends Character

signal jumped

const MOVE_SPEED = 12.0
const MOVE_ACCEL = 6.0
const MOVE_DECEL = 13.0
const AIR_ACCEL = 5.0
const AIR_DECEL = 1.0
const JUMP_STRENGTH = 12.0


# References
@onready var cam: Cam = %Cam
@onready var ray_cam: RayCast3D = %RayCam
@onready var ray_aim_cam: RayCast3D = %RayAimCam
@onready var ray_aim_player: RayCast3D = %RayAimPlayer
@onready var model: Node3D = %Model
@onready var aim_indicator: Crosshair = %Crosshair
@onready var area_melee: Area3D = %AreaMelee

var source_id := 0

static var first_person: bool = true

# Camera
var look_angle: Vector2
var cam_pos: Vector3
var floor_pos: Vector3
var cam_distance: float = 3.0

# Jumping
var allow_jump: bool = true
var allow_jump_release: bool = false
var since_jump_pressed: float = 999.0
var since_on_floor: float = 0.0
var allow_jump_vel_boost: bool = false

var allow_walljump: bool = false

# Shooting
@onready var weapon: Weapon = %Weapon

var input_direction: Vector2
var aim_target: Node3D
var aim_point: Vector3
var look_angle_prev: Vector2
var look_vel: Vector2 = Vector2.ZERO
@export var target_range_over_distance: Curve

var since_secondary_pressed: float = 999.0
var melee_reload_t: float = 0.0

var model_position: Vector3 = Vector3.ZERO
var velocity_prev: Vector3 = Vector3.ZERO

# Audio
var walk_cycle: float = 0.0
var walk_cycle_next_step: int = 0

@export var close_on_escape = false

#region Initialization

func _ready() -> void:
	source_id = EventStore.next_source_id()
	
	EventStore.push_event(
		EventStoreCommandAddChild.new(
			get_parent().source_id, 
			source_id, 
			preload("res://game/npc/player_ghost/npc_player_ghost.tscn"),
			global_transform))
	
	
	Main.player = self
	
	await get_tree().process_frame
	cam.reparent(get_parent())
	ray_cam.reparent(get_parent())
	
	weapon.player = self
	
	%Model.visible = not first_person

#endregion

#region Processing

func _process(delta: float) -> void:
	if Input.is_action_just_pressed("toggle_view"):
		first_person = not first_person
		%Model.visible = not first_person
	
	model_position = lerp(model_position, global_position, delta * 30.0)
	model.global_position = model_position
	
	#region Camera
	# Apply look_vel (controller input)
	look_angle += look_vel * 5.0 * delta
	
	# Clamp look angle
	look_angle.x = wrapf(look_angle.x, 0.0, TAU)
	look_angle.y = clamp(look_angle.y, -PI * 0.45, PI * 0.35)
	
	# Look Horizontal 
	cam.rotation.y = -look_angle.x - PI * 0.5
	
	# Look Vertical
	cam.rotation.x = ease(absf(look_angle.y), -1.2) * sign(look_angle.y) - 0.2
	cam.rotation.x = look_angle.y
	
	# Camera distance
	var cam_distance_to: float = 2.5 + ease(sin(melee_reload_t * PI * 0.7), 0.7) * 1.5
	var cam_up: float = 2.0
	
	if first_person:
		cam_distance_to = 0.0
		cam_up = 1.5
	
	var view_up_close_in: float = clampf(-look_angle.y + 1.3, 0.0, 1.0)
	view_up_close_in = ease(view_up_close_in, -2.0)
	view_up_close_in = remap(view_up_close_in, 0.0, 1.0, 0.9, 1.0)
	cam_distance_to *= view_up_close_in
	
	# Camera Up
	%RayUp.global_position.y = floor_pos.y + 1.0
	%RayUp.force_raycast_update()
	if %RayUp.is_colliding():
		cam_up = minf(cam_up,
				%RayUp.get_collision_point().y - %RayUp.global_position.y)
	
	# Camera collide with walls
	ray_cam.position = position + Vector3.UP * cam_up
	ray_cam.target_position = cam.basis.z * 4.0
	ray_cam.force_raycast_update()
	if ray_cam.is_colliding():
		cam_distance_to = minf(
				cam_distance_to,
				ray_cam.get_collision_point().distance_to(ray_cam.position) - 0.2)
	cam_distance = minf(cam_distance, cam_distance_to)
	cam_distance = move_toward(cam_distance, cam_distance_to, delta * 10.0)
	
	# Apply cam position
	if is_on_floor():
		floor_pos = global_position
	
	
	var cam_pos_to: Vector3 = model.global_position
	if first_person:
		cam_pos_to.y = cam_pos_to.y
	else:
		cam_pos_to.y = lerp(cam_pos_to.y, clampf(floor_pos.y, position.y - 4.0, position.y + 2.0), 0.4)
	cam_pos.x = cam_pos_to.x
	cam_pos.z = cam_pos_to.z
	cam_pos.y = lerp(cam_pos.y, cam_pos_to.y, delta * 8.0)
	cam.global_position = cam_pos + Vector3.UP * cam_up + cam.basis.z * cam_distance
	#endregion
	
	process_targets()
	process_target_indicators(delta)
	
	
	var t = global_transform
	t = t.rotated_local(Vector3.UP, PI * 0.5)
	EventStore.push_event(EventStoreCommandSet.new(source_id, "global_transform", t))


func _physics_process(delta: float) -> void:
	#region Input
	#var look_vel_to: Vector2 = Input.get_vector(
	#		"joy_left", "joy_right",
	#		"joy_down", "joy_up")
	#if look_vel_to.length() < 0.1:
	#	look_vel = lerp(look_vel, Vector2.ZERO, delta * 20.0)
	#else:
	#	look_vel = lerp(look_vel, look_vel_to, delta * 10.0)
	
	if Input.is_action_just_pressed("jump"):
		since_jump_pressed = 0.0
	else:
		since_jump_pressed += delta
	
	#endregion
	
	#region Movement
	input_direction = Input.get_vector(
			"left", "right",
			"forward", "backward")
	
	_process_movement(delta)
	_process_melee(delta)
	
	if is_on_floor():
		if since_on_floor > 0.2:
			_on_land()
		since_on_floor = 0.0
		allow_jump_vel_boost = true
	else:
		since_on_floor += delta
	
	weapon.process(delta)
	
	# Fall out of world
	if position.y < -20.0:
		position = Vector3.ZERO
		velocity = Vector3.ZERO
	
	look_angle_prev = look_angle
	velocity_prev = velocity

#endregion

#region Movement

func _process_movement(delta:float) -> void:
	# Rotate towards view direction
	if input_direction != Vector2.ZERO:
		rotate_towards_view_direction()
	else:
		rotate_towards_view_direction(delta * 2.0)
	
	# Movement
	var accel: float
	if input_direction == Vector2.ZERO:
		# Decelerate
		accel = MOVE_DECEL if is_on_floor() else AIR_DECEL
	else:
		# Accelerate
		accel = MOVE_ACCEL if is_on_floor() else AIR_ACCEL
	vel_hor_to(input_direction * MOVE_SPEED, accel * delta)
	
	# Gravity
	var gravity_scale: float = 1.0
	if absf(velocity.y) < 3.0:
		# Hovering at jump peak
		gravity_scale = 0.5
	if velocity.y < 0.2:
		gravity_scale *= 1.0 - melee_reload_t
	velocity.y -= GRAVITY * delta * gravity_scale
	
	
	# Jumping
	if (	is_jump_just_pressed(0.2) and since_on_floor < 0.1
			and allow_jump):
		jump()
	if allow_jump_release and not Input.is_action_pressed("jump"):
		# Stop jumping
		allow_jump_release = false
		if velocity.y > 0.0:
			velocity.y *= 0.5
	if not allow_jump and is_on_floor() and not allow_jump_release:
		# Reset jump state
		allow_jump = true
	
	# Jump velocity boost
	process_jump_vel_boost()
	
	# Apply movement
	apply_move_and_slide()
	
	if is_on_floor():
		walk_cycle += delta * vel_hor.length() / MOVE_SPEED * 5.0
		
		if walk_cycle > walk_cycle_next_step:
			walk_cycle_next_step += 1
			_on_step(walk_cycle_next_step % 2 == 0)


func _on_land() -> void:
	%AudioLand.play()
	cam.shake_shock(0.2, maxf(0.0, (-velocity_prev.y * 0.2 - 3.0)))
	
	if first_person:
		cam.shake_land(0.5, minf(absf(velocity_prev.y) / 20.0, 2.0))


func _on_step(left: bool) -> void:
	%AudioStep.pitch_scale = 0.4 + (0.1 if left else -0.1)
	%AudioStep.play()


func apply_move_and_slide() -> void:
	move_and_slide()
	var collision: KinematicCollision3D = get_last_slide_collision()
	if collision:
		var normal: Vector3 = collision.get_normal()
		if since_on_floor > 0.1 and melee_reload_t > 0.7 and allow_walljump and absf(normal.y) < 0.1:
			#velocity = (velocity_prev.bounce(normal) * Vector3(1.0, 0.0, 1.0)).normalized() * MOVE_SPEED * 2.0
			velocity = normal * MOVE_SPEED * 2.0
			allow_walljump = false
			velocity.y = JUMP_STRENGTH * 1.5
			%AudioWallbounce.play()


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
	jumped.emit()
	
	if first_person:
		cam.shake_land(0.4, 0.5)


func rotate_towards_view_direction(t: float = 1.0) -> void:
	rotation.y = lerp_angle(rotation.y, -look_angle.x,  t)


func process_jump_vel_boost() -> void:
	if (	allow_jump_vel_boost
			and not is_on_floor()
			and is_jump_just_pressed()
			and input_direction != Vector2.ZERO
			and vel_hor.length() > MOVE_SPEED * 0.2):
		allow_jump_vel_boost = false
		vel_hor_to(input_direction * MOVE_SPEED, 0.5)

#endregion

#region Targetting

func process_targets() -> void:
	if first_person:
		aim_target = null
		aim_dir = -cam.global_basis.z
		aim_point = cam.global_position + cam.basis.z * 100.0
		#printt(aim_dir)
		return
	# Aim target
	var target_range_sq: float = weapon.target_range ** 2
	
	ray_aim_player.global_rotation = Vector3.ZERO
	aim_target = null
	var aimables: Array[Node] = get_tree().get_nodes_in_group("aimables")
	var highest_fitness: float = -INF
	
	ray_aim_cam.rotation.x = 0.0
	
	# Aim up a bit
	ray_aim_cam.rotation.x += 0.1
	
	ray_aim_cam.force_raycast_update()
	if ray_aim_cam.is_colliding():
		aim_point = ray_aim_cam.get_collision_point()
	else:
		aim_point = cam.position - ray_aim_cam.global_basis.z * 100.0
	
	aim_dir = center_pos.direction_to(aim_point)
	var aim_dir_flat: Vector3 = (aim_dir * Vector3(1.0, 0.8, 1.0)).normalized()
	
	for aimable: Node in aimables:
		# In range
		var dist_sq: float = global_position.distance_squared_to(aimable.global_position)
		if dist_sq > target_range_sq:
			continue
		
		# Check dot product
		var target_width = 1.0 - target_range_over_distance.sample_baked(dist_sq / target_range_sq)
		target_width = -0.5 + pow(target_width, 0.2) * 1.5
		var aimable_dir_flat: Vector3 = center_pos.direction_to(aimable.center_pos)
		aimable_dir_flat = (aimable_dir_flat * Vector3(1.0, 0.5, 1.0)).normalized()
		var dot_product: float = aimable_dir_flat.dot(aim_dir_flat)
		if dot_product < target_width:
			continue
		
		# Check obstructions
		ray_aim_player.target_position = aimable.center_pos - ray_aim_player.global_position
		ray_aim_player.force_raycast_update()
		if ray_aim_player.is_colliding() and ray_aim_player.get_collider() != aimable:
			continue
		
		# Check greater fitness
		var fitness: float = (dot_product - target_width) / 0.1
		if dist_sq < 5.0 ** 2.0:
			fitness *= 1.2
		if fitness < highest_fitness:
			continue
		highest_fitness = fitness
		aim_target = aimable
	
	if aim_target:
		aim_dir = center_pos.direction_to(aim_target.center_pos)
		#printt(aim_dir)


func process_target_indicators(delta: float) -> void:
	# Aim target
	var aim_target_point = aim_target.center_pos if aim_target else aim_point
	var aim_pos: Vector2 = cam.camera.unproject_position(aim_target_point)
	aim_indicator.process(aim_pos, delta, aim_target)

#endregion

#region Melee

func _process_melee(delta) -> void:
	if Input.is_action_just_pressed("secondary"):
		since_secondary_pressed = 0.0
	else:
		since_secondary_pressed += delta
	
	melee_reload_t = move_toward(melee_reload_t, 0.0, delta / 0.8)
	
	if since_secondary_pressed < 0.2 and melee_reload_t <= 0.0:
		
		vel_hor *= 1.5
		allow_walljump = true
		melee_reload_t = 1.0
		since_secondary_pressed = 999.0
		%AudioMelee.play()
		%MeleeAttack.show()
		await get_tree().create_timer(0.2).timeout
		
		for body in area_melee.get_overlapping_bodies():
			if "melee" in body:
				body.melee()
			elif "melee" in body.get_parent():
				body.get_parent().melee()
		await get_tree().create_timer(0.1).timeout
		
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
		var mouse_speed: float = 0.1
		var mouse_motion: InputEventMouseMotion = event
		look_angle.x += mouse_motion.relative.x * mouse_speed / TAU
		look_angle.y -= mouse_motion.relative.y * mouse_speed / TAU * 0.7


func is_jump_just_pressed(grace: float = 0.1) -> bool:
	return since_jump_pressed < grace


#endregion


func die() -> void:
	get_tree().reload_current_scene()
