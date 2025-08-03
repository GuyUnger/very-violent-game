extends CanvasLayer

var tween: Tween

var t: float:
	get:
		return t
	set(value):
		t = value
		$ColorRect.material.set_shader_parameter("time", t)

func close(color: Color = Color.WHITE) -> void:
	$AudioStreamPlayer.play()
	$ColorRect.modulate = color
	if tween:
		tween.kill()
	tween = create_tween()
	t = 0.0
	tween.tween_property(self, "t", 0.5, 0.3)
	await tween.finished


func open() -> void:
	if tween:
		tween.kill()
	tween = create_tween()
	tween.tween_property(self, "t", 1.0, 0.3)
	await tween.finished


func _on_music_finished() -> void:
	$Music.stream = preload("res://game/gameplay01_loop.ogg")
	$Music.play()