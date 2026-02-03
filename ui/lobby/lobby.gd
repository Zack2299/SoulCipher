extends Node2D

#@onready var host_button: Button = $HBoxContainer/HostButton
#@onready var join_button: Button = $HBoxContainer/JoinButton
#@onready var start_button: Button = $StartButton
@onready var host_button: TextureButton = $NonSettings/NetworkButtons/VBoxContainer/HostButton
@onready var join_button: TextureButton = $NonSettings/NetworkButtons/VBoxContainer/JoinButton
@onready var start_button: TextureButton = $NonSettings/NetworkButtons/VBoxContainer/StartButton
@onready var avatar: Sprite2D = $NonSettings/Avatar
@onready var settings: Node2D = $Settings
@onready var non_settings: Node2D = $NonSettings
@onready var settings_area_2d: Area2D = $NonSettings/SettingsBook/Area2D
@onready var book_open_audio_stream_player: AudioStreamPlayer = $Settings/BookOpenAudioStreamPlayer
@onready var ip_line_edit: LineEdit = $Settings/VBoxContainer/IPContainer/IPLineEdit
@onready var port_line_edit: LineEdit = $Settings/VBoxContainer/PortContainer/PortLineEdit

const NUM_AVATARS = 8
const LOCAL_HOST = "127.0.0.1"
const DEFAULT_PORT = "8080"
var ip = LOCAL_HOST
var port = DEFAULT_PORT


func _ready() -> void:
	avatar.frame = NetworkManager.local_avatar_id
	start_button.visible = false
	host_button.pressed.connect(_on_host_button_pressed)
	join_button.pressed.connect(_on_join_button_pressed)
	start_button.pressed.connect(_on_start_button_pressed)


func _on_host_button_pressed():
	NetworkManager.host_game(int(port))
	
	host_button.visible = false
	join_button.visible = false
	#relocator.visible = true
	start_button.visible = true


func _on_join_button_pressed():
	NetworkManager.join_game(ip, int(port))
	
	host_button.visible = false
	join_button.visible = false


func _on_start_button_pressed():
	NetworkManager.start_game_for_all()


func _on_left_arrow_clicked() -> void:
	if avatar.frame == 0:
		avatar.frame = NUM_AVATARS - 1
	else:
		avatar.frame -= 1
	#avatar.frame = (avatar.frame - 1) % NUM_AVATARS
	NetworkManager.local_avatar_id = avatar.frame


func _on_right_arrow_clicked() -> void:
	avatar.frame = (avatar.frame + 1) % NUM_AVATARS
	NetworkManager.local_avatar_id = avatar.frame


func _on_settings_clicked() -> void:
	SceneTransition.reveal_hide_transition(settings, non_settings)
	settings_area_2d.visible = false

	
func _on_open_book_clicked() -> void:
	SceneTransition.reveal_hide_transition(non_settings, settings)
	settings_area_2d.visible = true

func _on_player_name_line_edit_text_changed(new_text: String) -> void:
	NetworkManager.local_username = new_text
