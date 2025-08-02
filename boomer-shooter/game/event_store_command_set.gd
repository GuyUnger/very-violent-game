extends EventStoreCommand
class_name EventStoreCommandSet

@export var property:String
@export var value:Variant = null

func _init(source_id:int, property:StringName, value) -> void:
	self.time = EventStore.delta_sum_
	self.source_id = source_id
	self.property = property
	self.value = value


func replay() -> void:
	var source = EventStore.sources.get(source_id)
	if not source or not is_instance_valid(source):
		return

	source.set(property, value)
