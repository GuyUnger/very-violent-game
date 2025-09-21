extends Area3D

@export var next_level: String

var entered: bool = false

var is_open: bool = false

func _ready() -> void:
	Main.instance.enemy_killed.connect(_on_enemy_killed)
	
	await get_tree().process_frame
	_on_enemy_killed()


func _on_enemy_killed() -> void:
	await get_tree().process_frame
	if Main.instance.enemies_killed >= Main.instance.enemies_total:
		open()


func open() -> void:
	%Light.visible = true
	is_open = true


func _on_body_entered(body:Node3D) -> void:
	if not is_open:
		return
	if entered:
		return
	entered = true
	var tween = create_tween()
	tween.tween_property(Main.player.cam.camera, "fov", 30.0, 1.0)
	get_tree().paused = true
	EventStore.clear()
	await Transition.close()
	get_tree().change_scene_to_file(next_level)
	Transition.open()
