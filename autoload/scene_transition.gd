extends CanvasLayer

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var audio_stream_player: AudioStreamPlayer = $AudioStreamPlayer

func change_scene(target_scene: PackedScene) -> void:
	animation_player.play("fade") # fade to black
	audio_stream_player.play()
	
	await animation_player.animation_finished
	
	get_tree().change_scene_to_packed(target_scene)
	
	animation_player.play_backwards("fade")
