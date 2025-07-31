extends NPC
class_name NPCPlayerGhost

var source_id:int

func _ready() -> void:
	if source_id:
		EventStore.register_source(source_id, self)
