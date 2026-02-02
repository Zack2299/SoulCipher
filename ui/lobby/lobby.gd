extends Node2D

#@onready var host_button: Button = $HBoxContainer/HostButton
#@onready var join_button: Button = $HBoxContainer/JoinButton
#@onready var start_button: Button = $StartButton
@onready var host_button: TextureButton = $NetworkButtons/VBoxContainer/HostButton
@onready var join_button: TextureButton = $NetworkButtons/VBoxContainer/JoinButton
@onready var start_button: TextureButton = $NetworkButtons/VBoxContainer/StartButton
@onready var avatar: Sprite2D = $Avatar

@onready var relocator: Node2D = $Relocator

const LOCAL_HOST = "127.0.0.1"
const DEFAULT_PORT = "8080"
var ip = LOCAL_HOST
var port = DEFAULT_PORT

func _ready() -> void:
	avatar.frame = NetworkManager.local_avatar_id
	relocator.visible = false
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
		avatar.frame = 7
	else:
		avatar.frame -= 1
	#avatar.frame = (avatar.frame - 1) % 8
	NetworkManager.local_avatar_id = avatar.frame


func _on_right_arrow_clicked() -> void:
	avatar.frame = (avatar.frame + 1) % 8
	NetworkManager.local_avatar_id = avatar.frame
