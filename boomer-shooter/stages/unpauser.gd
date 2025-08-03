extends CanvasLayer

var t: float = 0.0

func _process(delta: float) -> void:
	t += delta / 0.2
	$Label.visible = fmod(t, 1.0) < 0.6
	if Input.is_action_just_pressed("primary") or Input.is_action_just_pressed("left") or Input.is_action_just_pressed("right") or Input.is_action_just_pressed("forward") or Input.is_action_just_pressed("backward"):
	#if Input.is_action_just_pressed("primary"):
		get_tree().paused = false
		hide()
		$AudioUnpause.play()
