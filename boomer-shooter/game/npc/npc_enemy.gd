@tool
extends NPC
class_name NPCEnemy

var source_id := 0

var is_hit_damage: int:
	set(value):
		if value > 0:
			super.hit(value)

var is_meleed: bool:
	set(value):
		if value:
			super.melee()
			
			$AudioHurt.unit_size = 10
			$AudioHurt.volume_db = 5.0
			$AudioHurt.play()
			
			var x := preload("res://game/fx/bloot_line.tscn").instantiate()
			$CollisionShape3D.add_child(x)
			x.position.y += 0.5
			x.look_at(Main.instance.player.global_position + Vector3.UP * 2.0, Vector3.UP, true)


func _ready() -> void:
	source_id = EventStore.unique_source_id(self)
	EventStore.register_source(source_id, self)
	super()


func hit(damage: int) -> void:
	EventStore.push_event(EventStoreCommandSet.new(source_id, "is_hit_damage", damage))
	is_hit_damage = damage


func melee() -> void:
	EventStore.push_event(EventStoreCommandSet.new(source_id, "is_meleed", true))
	is_meleed = true
