extends Node

@onready var nek = $"../Nek"
@onready var head = $"../Nek/Head"
@onready var eyes = $"../Nek/Head/Eyes"
@onready var camera = $"../Nek/Head/Eyes/Camera"
@onready var raycast = $"../RayCast3D"
@onready var standing_collision = $"../StandingCollision"
@onready var crouching_collision = $"../CrouchingCollision"

#speed
var current_speed = 5.0
const walking_speed = 5.0
const sprinting_speed = 8.0
const crouching_speed = 3.0

#states
var walking = false
var sprinting = false
var crouching = false
var sliding = false

#movement
const crouching_depth = -0.5
const jump_velocity = 6.5 #default 4.5
const lerp_speed = 10.0
const air_lerp_speed = 3.0

#input
var direction = Vector3.ZERO

var head_bobbing_vector = Vector2.ZERO
var head_bobbing_intensity = 0
var head_bobbing_index = 0

var free_look_tilt_amount = 3.0

#sliding
var slide_timer = 0
var slide_vector = Vector2.ZERO
const slide_timer_max = 1.0
const slide_speed = 10.0

const head_bobbing_sprinting_speed = 22.0
const head_bobbing_walking_speed = 14.0
const head_bobbing_crouching_speed = 10.0

const head_bobbing_sprinting_intensity = 0.2
const head_bobbing_walking_intensity = 0.1
const head_bobbing_crouching_intensity = 0.05

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

func update_movement(player, delta):
	
	var dlerp = delta * lerp_speed
	var input_dir = Input.get_vector("left", "right", "forward", "backward")
	
	
	if Input.is_action_pressed("crouch") or sliding:
		current_speed = lerp(current_speed, crouching_speed, dlerp)
		head.position.y = lerp(head.position.y, crouching_depth, dlerp)
		standing_collision.disabled = true
		crouching_collision.disabled = false
		
		if sprinting and input_dir != Vector2.ZERO:
			sliding = true
			slide_timer = slide_timer_max
			slide_vector = input_dir
			player.free_looking = true
			#print("slide begin")
		
		walking = false
		sprinting = false
		crouching = true
	elif !raycast.is_colliding():
		standing_collision.disabled = false
		crouching_collision.disabled = true
		
		head.position.y = lerp(head.position.y, 0.0, dlerp)
		crouching = false
		
	if !crouching:
		if Input.is_action_pressed("sprint"):
			current_speed = lerp(current_speed, sprinting_speed, dlerp)
			walking = false
			sprinting = true
			crouching = false
		else:
			current_speed = lerp(current_speed, walking_speed, dlerp)
			walking = true
			sprinting = false
			crouching = false
	
	#Free looking
	if Input.is_action_pressed("free_look") || sliding:
		player.free_looking = true
		if sliding:
			camera.rotation.z = lerp(camera.rotation.z, -deg_to_rad(7.0), dlerp)
		else:
			camera.rotation.z = -deg_to_rad(nek.rotation.y * free_look_tilt_amount)
	else:
		player.free_looking = false
		nek.rotation.y = lerp(nek.rotation.y, 0.0, dlerp)
		camera.rotation.z = lerp(camera.rotation.z, 0.0, dlerp)

	
	#Sliding
	if sliding:
		slide_timer -= delta
		if slide_timer <= 0:
			sliding = false
			#print("slide end")
			player.free_looking = false

	#Headbob
	if sprinting:
		head_bobbing_intensity = head_bobbing_sprinting_intensity
		head_bobbing_index += head_bobbing_sprinting_speed * delta
	elif walking:
		head_bobbing_intensity = head_bobbing_walking_intensity
		head_bobbing_index += head_bobbing_walking_speed * delta
	elif crouching:
		head_bobbing_intensity = head_bobbing_crouching_intensity
		head_bobbing_index += head_bobbing_crouching_speed * delta
		
	if player.is_on_floor() and !sliding and input_dir != Vector2.ZERO:
		head_bobbing_vector.y = sin(head_bobbing_index)
		head_bobbing_vector.x = sin(head_bobbing_index * 0.5) + 0.5
		
		eyes.position.y = lerp(eyes.position.y, head_bobbing_vector.y * (head_bobbing_intensity * 0.5), dlerp)
		eyes.position.x = lerp(eyes.position.x, head_bobbing_vector.x * head_bobbing_intensity, dlerp)
	else:
		eyes.position.y = lerp(eyes.position.y, 0.0, dlerp)
		eyes.position.x = lerp(eyes.position.x, 0.0, dlerp)

	#Gravity
	if not player.is_on_floor():
		player.velocity.y -= gravity * delta

	#Jump
	if Input.is_action_just_pressed("jump") and player.is_on_floor():
		player.velocity.y = jump_velocity
		sliding = false
	
	if player.is_on_floor():
		direction = lerp(direction, (player.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized(), dlerp)
	else:
		if input_dir != Vector2.ZERO:
			direction = lerp(direction, (player.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized(), delta * air_lerp_speed)
	
	if sliding:
		direction = (player.transform.basis * Vector3(slide_vector.x, 0, slide_vector.y)).normalized()
		current_speed = (slide_timer + 0.1) * slide_speed
	
	if direction:
		player.velocity.x = direction.x * current_speed
		player.velocity.z = direction.z * current_speed
	else:
		player.velocity.x = move_toward(player.velocity.x, 0, current_speed)
		player.velocity.z = move_toward(player.velocity.z, 0, current_speed)
