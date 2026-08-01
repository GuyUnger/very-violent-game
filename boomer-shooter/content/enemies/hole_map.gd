extends Sprite2D

func _ready() -> void:
	var d := range(get_child_count())
	d.shuffle()
	
	for child in get_children():
		child.modulate = Color.from_rgba8(255 - d[child.get_index()], 255 - d[child.get_index()], 255 - d[child.get_index()])
		child.rotation = PI * 2.0 * randf()
