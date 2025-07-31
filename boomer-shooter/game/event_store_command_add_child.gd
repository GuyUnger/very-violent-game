extends EventStoreCommand
class_name EventStoreCommandAddChild

@export var child_source_id:StringName
@export var packed_scene:PackedScene

func _init(source_id, child_source_id, packed_scene) -> void:
	self.time = EventStore.delta_sum_
	self.node_id = source_id
	self.child_source_id = child_source_id
	self.packed_scene = packed_scene

func replay() -> void:
	var source:Object = EventStore.sources.get(node_id)
	if not source:
		push_error("EVENT SOURCE DOES NOT EXIST")
		return
	
	var child = packed_scene.instantiate()
	child.source_id = child_source_id
	source.add_child(child)
