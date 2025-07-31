extends EventStoreCommand
class_name EventStoreCommandSet

@export var property:String
@export var value:Variant = null

func _init(source_id:String, property:StringName, value) -> void:
	self.time = EventStore.delta_sum_
	self.node_id = source_id
	self.property = property
	self.value = value


func replay() -> void:
	var source:Object = EventStore.sources.get(node_id)
	if not source:
		push_error("EVENT SOURCE DOES NOT EXIST")
		return
	
	source.set(property, value)
