extends CanvasLayer

@onready var animation_player: AnimationPlayer = $AnimationPlayer
#@onready var audio_stream_player: AudioStreamPlayer = $AudioStreamPlayer
@onready var woosh_audio_stream_player: AudioStreamPlayer = $WooshAudioStreamPlayer
@onready var door_audio_stream_player: AudioStreamPlayer = $DoorAudioStreamPlayer

var previous_room: String = "staircase"
var current_room: String = "staircase"

var room_history_queue: Array = []


func _ready() -> void:
	room_history_queue.clear()
	room_history_queue.push_front(current_room)
	
	previous_room = "staircase"
	current_room = "staircase"


func change_scene_packed(target_scene: PackedScene) -> void:
	animation_player.play("fade") # fade to black
	
	await animation_player.animation_finished
	
	#woosh_audio_stream_player.play()
	
	# change scene (deletion)
	get_tree().change_scene_to_packed(target_scene)
	
	#door_audio_stream_player.play()
	animation_player.play_backwards("fade")


func reveal_hide_transition(target_reveal: Node = null, target_hide: Node = null):
	animation_player.play("fade")
	
	await animation_player.animation_finished
	
	if target_reveal:
		target_reveal.visible = true
		
	if target_hide:
		target_hide.visible = false
		
	animation_player.play_backwards("fade")


func set_visibility_transition(target: Node, show: bool):
	animation_player.play("fade")
	
	await animation_player.animation_finished
	
	target.visible = show
		
	animation_player.play_backwards("fade")

func change_scene_room_name(target_room_name: String, target_room: Node, room_to_set_invisible: Node, set_parent_invisible: bool, used_door_index: int = -1) -> void:
	animation_player.play("fade")
	
	await animation_player.animation_finished
	
	#woosh_audio_stream_player.play()
	
	if set_parent_invisible:
		# store the room we are leaving AND the door index used to leave it
		room_history_queue.push_back({
			"name": current_room,
			"door_index": used_door_index
		})
		previous_room = current_room
	else:
		woosh_audio_stream_player.play()
		
	current_room = target_room_name
	
	#if current_room == "staircase":
		#door_audio_stream_player.play()

	if target_room:
		target_room.visible = true
	if room_to_set_invisible:
		room_to_set_invisible.visible = false
	
	animation_player.play_backwards("fade")


func zoom_and_recenter(door_position: Vector2, room_center: Vector2, duration: float = 1.2):
	var camera = get_viewport().get_camera_2d()
	if not camera: return

	# snap to door immediately while the screen is black
	camera.position_smoothing_enabled = false # disable smoothing so it doesn't "slide" during the fade
	camera.global_position = door_position
	camera.zoom = Vector2(10, 10) # start very close


	var tween = create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	# tween both properties back to "normal"
	tween.tween_property(camera, "global_position", room_center, duration)
	tween.tween_property(camera, "zoom", Vector2(3.0, 3.0), duration)
	
	# re-enable smoothing once the movement is done
	tween.chain().tween_callback(func(): camera.position_smoothing_enabled = true)
