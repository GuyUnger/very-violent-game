extends Area3D

var source_id := 0
var is_ghost := false
var track_in_event_store := true

func _ready() -> void:
	if source_id != 0:
		is_ghost = true
	elif track_in_event_store:
		source_id = EventStore.next_source_id()
		EventStore.push_event(EventStoreCommandAddChild.new(get_parent().source_id, source_id, load(scene_file_path), global_transform))
	
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	
	for body in get_overlapping_bodies():
		if "melee" in body:
			body.melee()
		elif "melee" in body.get_parent():
			body.get_parent().melee()
			
	queue_free()
