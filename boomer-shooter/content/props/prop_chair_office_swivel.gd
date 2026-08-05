extends Prop

var spin_tween_: Tween

func hit(pos:Vector3, normal:Vector3, damage, is_nested := false) -> void:
	super(pos, normal, damage, is_nested)
	
	if spin_tween_:
		spin_tween_.kill()
	spin_tween_ = create_tween()
	spin_tween_.set_trans(Tween.TRANS_SINE)
	spin_tween_.set_ease(Tween.EASE_OUT)
	spin_tween_.tween_property(%Seat, "rotation:y", %Seat.rotation.y + randf() * 20.0, 4.0)
	
