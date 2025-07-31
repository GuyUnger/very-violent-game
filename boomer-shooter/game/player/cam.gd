class_name Cam
extends Node3D

var shakes: Array = []
@onready var camera: Camera3D = %Camera


func _process(delta: float) -> void:
	camera.transform = Transform3D.IDENTITY
	
	# Process shakes
	for shake: Shake in shakes:
		shake.process(delta)
		camera.transform *= shake.transform
		#transform.origin += shake.transform.origin
		#transform.
	
	
	# Remove completed shakes
	var i:int = 0
	while i < shakes.size():
		if shakes[i].t <= 0.0:
			shakes.remove_at(i)
		else:
			i += 1


func shake_rumble(p_duration: float = 0.7, p_strength: float = 1.0,
			p_frequency: float = 8.0, p_curve: float = 2.0) -> void:
	shakes.push_back(ShakeRumble.new(p_duration, p_strength, p_frequency, p_curve))


func shake_shock(p_duration: float = 0.2, p_strength: float = 1.0,
			p_fps: float = 30.0, p_curve: float = 1.0) -> void:
	shakes.push_back(ShakeShock.new(p_duration, p_strength, p_fps, p_curve))


func shake_land(p_duration: float = 0.5, p_strength: float = 1.0) -> void:
	shakes.push_back(ShakeLand.new(p_duration, p_strength))

class Shake extends RefCounted:
	var duration: float
	var strength: float
	var curve: float
	
	var t: float
	var pct: float:
		get:
			return t / duration
	
	var transform := Transform3D()
	
	var offset: Vector2:
		get:
			return Vector2(transform.origin.x, transform.origin.y)
		set(value):
			transform.origin.x = value.x
			transform.origin.y = value.y
	
	var offset_forward: float:
		get:
			return transform.origin.z
		set(value):
			transform.origin.z = value
	
	var offset_look_at: Vector2:
		get:
			var euler: Vector3 = transform.basis.get_euler()
			return Vector2(euler.x, euler.y)
		set(value):
			var euler: Vector3 = transform.basis.get_euler()
			euler.x = value.x
			euler.y = value.y
			transform.basis = Basis.from_euler(euler)
	
	var roll: float:
		get:
			return transform.basis.get_euler().z
		set(value):
			var euler: Vector3 = transform.basis.get_euler()
			euler.z = value
			transform.basis = Basis.from_euler(euler)
	
	
	func process(delta) -> void:
		t -= delta
		_process(delta)
	
	
	func _process(_delta) -> void:
		pass


class ShakeRumble extends Shake:
	
	var frequency: float
	var direction: float
	var t_random: float
	
	
	func _init(p_duration: float, p_strength: float, p_frequency: float, p_curve: float) -> void:
		t = p_duration
		duration = p_duration
		strength = p_strength
		frequency = p_frequency
		curve = p_curve
		
		direction = 1.0 if randf() < 0.5 else -1.0
		t_random = randf() * TAU
	
	
	func _process(delta: float) -> void:
		var angle: float = t * frequency * TAU * direction + t_random
		offset = Vector2.from_angle(angle) * strength * ease(pct, curve) * 0.1
		roll = sin(angle * 0.47) * strength * ease(pct, curve) * 0.05
		offset_look_at = Vector2.from_angle(angle) * strength * ease(pct, curve) * 0.03


class ShakeShock extends Shake:
	var fps: float
	var frame_t: float = 0.0
	var offset_prev: Vector2
	var offset_next: Vector2
	var offset_look_at_prev: Vector2
	var offset_look_at_next: Vector2
	var offset_roll_prev: float = 0.0
	var offset_roll_next: float = 0.0
	
	
	func _init(p_duration: float, p_strength: float, p_fps: float, p_curve: float) -> void:
		t = p_duration
		fps = p_fps
		duration = p_duration
		strength = p_strength
		curve = p_curve
		offset_next = Vector2.from_angle(randf() * TAU)
		offset_look_at_next = Vector2.from_angle(randf() * TAU)
	
	
	func _process(delta: float) -> void:
		frame_t += delta * fps
		if frame_t >= 1.0:
			frame_t -= 1.0
			
			var prev: Vector2 = offset_next
			offset_next = offset_prev.rotated(PI + randf_range(-1.0, 1.0) * 4.0)
			offset_prev = prev
			
			var prev_look_at: Vector2 = offset_look_at_next
			offset_look_at_next = offset_look_at_prev.rotated(PI + randf_range(-1.0, 1.0) * 4.0)
			offset_look_at_prev = prev_look_at
			
			offset_roll_prev = offset_roll_next
			offset_roll_next = randf_range(-1.0, 1.0)
		
		var strength_curved: float = strength * ease(pct, curve)
		
		# Offset
		offset = offset_prev.lerp(offset_next, ease(frame_t, -3.0)) * strength_curved * 0.04
		
		# Look at
		offset_look_at = offset_look_at_prev.lerp(offset_look_at_next, ease(frame_t, -2.0)) * strength_curved * 0.01
		
		# Forward
		offset_forward = -sin(frame_t * PI) * 0.03
		
		# Roll
		roll = lerpf(offset_roll_prev, offset_roll_next, ease(frame_t, -2.0)) * strength_curved * 0.03


class ShakeLand extends Shake:
	
	
	func _init(p_duration: float, p_strength: float) -> void:
		t = p_duration
		duration = p_duration
		strength = p_strength
		curve = 1.0
	
	
	func _process(delta: float) -> void:
		offset_look_at.x = -sin(pct * PI) * 0.05 * pct * strength
		offset.y = -sin(pct * PI) * 0.8 * pct * strength