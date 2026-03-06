extends AudioStreamPlayer

var muted = false

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if not playing:
		play()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("mute_music"):
		muted = not muted
		if muted:
			volume_db = -80
		else:
			volume_db = -14
