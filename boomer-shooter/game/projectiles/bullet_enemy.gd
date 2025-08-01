extends Node3D

var source_id: int

var direction: Vector3
var speed: float = 30.0

var damage: int = 5

var dead: bool = false:
	set(value):
		if value:
			queue_free()


func _ready() -> void:
	if source_id == 0:
		direction = global_transform.basis.z.normalized()
		EventStore.push_event(EventStoreCommandSet.new(source_id, "direction", direction))


func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta


func _on_area_3d_body_entered(body:Node3D) -> void:
	EventStore.push_event(EventStoreCommandSet.new(source_id, "dead", true))
	if "hit" in body:
		body.hit(self)
	queue_free()
