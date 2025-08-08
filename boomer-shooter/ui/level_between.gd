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
	$Music.stream = tracks[track_num]
	$Music.play()


func play_end() -> void:
	$Music.stream = preload("res://content/music/end_loop.ogg")
	$Music.play()

@onready var intros: Array = [
	preload("res://content/music/gameplay01_intro.ogg"),
	preload("res://content/music/gameplay02_intro.ogg"),
	
]
@onready var tracks: Array = [
	preload("res://content/music/gameplay01_loop.ogg"),
	preload("res://content/music/gameplay02_loop.ogg"),
]

var track_num: int = -1
func play_track(p_track_num: int) -> void:
	if track_num == p_track_num:
		return
	track_num = p_track_num
	$Music.stream = intros[track_num]
	$Music.play()
	