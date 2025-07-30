extends CharacterBody3D

@onready var nek = $Nek
@onready var head = $Nek/Head

@onready var movement = $Movement
@onready var pickup = $Pickup

const mouse_sensitivity = 0.25

var free_looking = false
var push_force = 1

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	

func _input(event):
	if event is InputEventMouseMotion:
		if free_looking:
			nek.rotate_y(deg_to_rad(-event.relative.x * mouse_sensitivity))
			nek.rotation.y = clamp(nek.rotation.y, deg_to_rad(-120), deg_to_rad(120))
		else:
			rotate_y(deg_to_rad(-event.relative.x * mouse_sensitivity))
		head.rotate_x(deg_to_rad(-event.relative.y * mouse_sensitivity))
		head.rotation.x = clamp(head.rotation.x, deg_to_rad(-89), deg_to_rad(89))
	
	if event is InputEventKey:
		if event.is_action_pressed("exit"):
			get_tree().quit()
		if event.is_action_pressed("fullscreen"):
			if DisplayServer.window_get_mode(0) != DisplayServer.WINDOW_MODE_FULLSCREEN:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN, 0)
			else:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED, 0)
				
	if event.is_action_pressed("primary"):
		pickup.pick_object()
		
	if event.is_action_pressed("secondary"):
		pickup.drop_object()

func _physics_process(delta):
	movement.update_movement(self, delta)
	move_and_slide()
	for i in get_slide_collision_count():
		var c = get_slide_collision(i)
		if c.get_collider() is RigidBody3D:
			c.get_collider().apply_central_impulse(-c.get_normal() * push_force)
