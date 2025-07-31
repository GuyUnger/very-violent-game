extends NPC
class_name NPCPlayerGhost

var source_id:StringName

func _ready() -> void:
	EventStore.register_source(source_id, self)
