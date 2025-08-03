extends CanvasLayer

var last_life: int = 0


func _ready() -> void:
	get_tree().paused = false
	await get_tree().create_timer(1.0).timeout
	$AudioContinue.play()
	
	%LabelComplete.show()
	await get_tree().create_timer(2.0).timeout
	$AudioContinue.play()
	%LabelLife.show()
	
	await get_tree().create_timer(0.5).timeout
	var tween: Tween = create_tween()
	
	tween.tween_method(set_lifes, 0, Main.clones, min(1.0 + Main.clones / 10.0, 8.0)).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_IN_OUT)
	
	await tween.finished
	
	await get_tree().create_timer(1.0).timeout
	%AudioContinue.play()
	
	%LabelThanks.show()
	
	await get_tree().create_timer(1.0).timeout
	%AudioContinue.play()
	%LabelCredits.show()


func set_lifes(value) -> void:
	if value > last_life:
		$AudioLife.play()
		$AudioLife.pitch_scale = 0.8 + (value / 100.0) * 0.4
		last_life = ceili(value)

	%LabelLife.text = "%d Lifes" % value
