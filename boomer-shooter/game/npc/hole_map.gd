extends Control

func _ready() -> void:
	var c = range(256)
	c.shuffle()
	
	for i in c:
		var x := MarginContainer.new()
		x.custom_minimum_size.x = randf_range(30, 50)
		x.custom_minimum_size.y = randf_range(30, 50)

		var tr := TextureRect.new()
		tr.texture = preload("res://content/textures/hole_texture.png")
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		x.add_child(tr)
		tr.modulate = Color.from_rgba8(1 + i, 0, 0)
		add_child(x)
		
		
