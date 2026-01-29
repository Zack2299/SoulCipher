extends CanvasLayer

@onready var animation_player: AnimationPlayer = $AnimationPlayer
#@onready var audio_stream_player: AudioStreamPlayer = $AudioStreamPlayer
@onready var woosh_audio_stream_player: AudioStreamPlayer = $WooshAudioStreamPlayer
@onready var door_audio_stream_player: AudioStreamPlayer = $DoorAudioStreamPlayer

var previous_room: String = "staircase"
var current_room: String = "staircase"

var room_history_queue: Array = []


func _ready() -> void:
	room_history_queue.push_front(current_room) # should never reach here


func change_scene_packed(target_scene: PackedScene) -> void:
	animation_player.play("fade") # fade to black
	woosh_audio_stream_player.play()
	
	await animation_player.animation_finished
	
	# change scene (deletion)
	get_tree().change_scene_to_packed(target_scene)
	
	#door_audio_stream_player.play()
	
	animation_player.play_backwards("fade")


func change_scene_room_name(target_room_name: String, target_room: Node, room_to_set_invisible: Node, set_parent_invisible: bool) -> void:
	animation_player.play("fade") # fade to black
	woosh_audio_stream_player.play()
	
	await animation_player.animation_finished
	
	if set_parent_invisible:
		room_history_queue.push_front(current_room)
	SceneTransition.current_room = target_room_name

	# change scene (no deletion)
	if target_room:
		target_room.visible = true
		
	if room_to_set_invisible:
		room_to_set_invisible.visible = false
	
	#door_audio_stream_player.play()
	
	animation_player.play_backwards("fade")
