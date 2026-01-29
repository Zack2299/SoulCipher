extends CanvasLayer

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var audio_stream_player: AudioStreamPlayer = $AudioStreamPlayer

func change_scene_packed(target_scene: PackedScene) -> void:
	animation_player.play("fade") # fade to black
	audio_stream_player.play()
	
	await animation_player.animation_finished
	
	get_tree().change_scene_to_packed(target_scene)
	
	animation_player.play_backwards("fade")


func change_scene_room_name(target_room: Node, room_to_set_invisible: Node) -> void:
	animation_player.play("fade") # fade to black
	audio_stream_player.play()
	
	await animation_player.animation_finished
	
	if target_room:
		target_room.visible = true
	room_to_set_invisible.visible = false
	
	animation_player.play_backwards("fade")
