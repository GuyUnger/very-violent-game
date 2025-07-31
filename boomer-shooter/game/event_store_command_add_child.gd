extends EventStoreCommand
class_name EventStoreCommandAddChild

@export var child_source_id:int
@export var packed_scene:PackedScene
@export var transform:Transform3D

func _init(source_id, child_source_id, packed_scene, transform) -> void:
	self.time = EventStore.delta_sum_
	self.source_id = source_id
	self.child_source_id = child_source_id
	self.packed_scene = packed_scene
	self.transform = transform

func replay() -> void:
	var source:Object = EventStore.sources.get(source_id)
	if not source:
		push_error("EVENT SOURCE DOES NOT EXIST")
		return
	
	var child = packed_scene.instantiate()
	child.source_id = child_source_id
	child.transform = transform
	source.add_child(child)
