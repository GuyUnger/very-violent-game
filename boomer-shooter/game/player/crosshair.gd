class_name Crosshair
extends Node2D

var since_hit: float = 0.0


func process(target_pos:Vector2, delta:float, target) -> void:
	visible = target_pos != Vector2.ZERO
	
	if not visible:
		return
	
	var arrow_distance: float
	if target:
		rotation += delta * TAU * 0.5
		
		arrow_distance = 0.0
		if target.health < target.max_health * 0.333:
			modulate = Color.RED
		elif target.health < target.max_health * 0.666:
			modulate = Color.ORANGE
		else:
			modulate = Color.GREEN
	else:
		#arrow_distance = 36.0
		arrow_distance = -10.0
		modulate = Color.WHITE
		rotation = PI * 0.25
	arrow_distance -= (1.0 - since_hit) * 40.0
	#position = lerp(position, target_pos, delta * accel)
	position = target_pos
	
	since_hit = move_toward(since_hit, 1.0, delta / 0.3)
	
	scale = Vector2.ONE * (0.2 + maxf(0.1 - since_hit, 0.0))
	
	#if target:
	#else:
	#	scale = Vector2.ONE * 0.2
	
	for i in 4:
		var arrow = get_child(i)
		arrow.position = Vector2.from_angle(i * TAU / 4.0 - PI * 0.5) * - arrow_distance
