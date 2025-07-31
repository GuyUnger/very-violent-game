extends Node3D

@export var speed := 30.0

var source_id := 0
var is_ghost := false

func _ready() -> void:
	if source_id == 0:
		source_id = EventStore.next_source_id()
		EventStore.push_event(EventStoreCommandAddChild.new(get_parent().source_id, source_id, load(scene_file_path)))
	else:
		is_ghost = true
	
	EventStore.register_source(source_id, self)

func _physics_process(delta: float) -> void:
	if not is_ghost:
		var direction = global_transform.basis.z.normalized()
		global_position += direction * delta * speed
	
		EventStore.push_event(EventStoreCommandSet.new(source_id, "global_transform", global_transform))
