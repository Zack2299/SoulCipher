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
@onready var ip_line_edit: LineEdit = $Settings/Settings/VBoxContainer/IPContainer/IPLineEdit
@onready var port_line_edit: LineEdit = $Settings/Settings/VBoxContainer/PortContainer/PortLineEdit
@onready var host_join_audio_stream_player: AudioStreamPlayer = $HostJoinAudioStreamPlayer
@onready var start_audio_stream_player: AudioStreamPlayer = $StartAudioStreamPlayer
@onready var round_line_edit: LineEdit = $Settings/Settings/VBoxContainer/RoundContainer/RoundLineEdit
@onready var turn_line_edit: LineEdit = $Settings/Settings/VBoxContainer/TurnContainer/TurnLineEdit
@onready var cost_line_edit: LineEdit = $Settings/Settings/VBoxContainer/CostContainer/CostLineEdit
@onready var turn_duration_line_edit: LineEdit = $Settings/Settings/VBoxContainer/TurnDurationContainer/TurnDurationLineEdit
@onready var lead_line_edit: LineEdit = $Settings/Settings/VBoxContainer/LeadContainer/LeadLineEdit

const NUM_AVATARS = 8
const LOCAL_HOST = "127.0.0.1"
const DEFAULT_PORT = "8080"
var ip = LOCAL_HOST
var port = DEFAULT_PORT

var retry_count = 0
const MAX_RETRIES = 1
var is_attempting_connection = false

var multiplayer_info: MultiplayerInfo

func _ready() -> void:
	avatar.frame = NetworkManager.local_avatar_id
	start_button.visible = false
	host_button.pressed.connect(_on_host_button_pressed)
	join_button.pressed.connect(_on_join_button_pressed)
	start_button.pressed.connect(_on_start_button_pressed)
	
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.connected_to_server.connect(_on_connection_success)
	
	multiplayer_info = MultiplayerInfo.load_info()
	
	if multiplayer_info == null:
		multiplayer_info = MultiplayerInfo.new()
	
	port_line_edit.placeholder_text = multiplayer_info.last_used_port
	ip_line_edit.placeholder_text = multiplayer_info.last_used_ip


func save_settings():
	if round_line_edit.text and int(round_line_edit.text) > 0:
		GameManager.total_tracks = int(round_line_edit.text)
	if turn_line_edit.text and int(turn_line_edit.text) > 0:
		GameManager.total_rounds = int(turn_line_edit.text)
	if cost_line_edit.text and float(cost_line_edit.text) > 0:
		GameManager.cost_multiplier = float(cost_line_edit.text)
	if turn_duration_line_edit.text and int(turn_duration_line_edit.text) > 0:
		GameManager.max_turn_time = int(turn_duration_line_edit.text)
	if lead_line_edit.text and int(lead_line_edit.text) > 0:
		GameManager.num_cards = int(lead_line_edit.text)


func validate_ip_and_port() -> bool:
	if ip_line_edit.text.is_empty():
		ip = ip_line_edit.placeholder_text
		multiplayer_info.last_used_ip = ip # for when auto is toggled on
	else:
		ip = ip_line_edit.text
		multiplayer_info.last_used_ip = ip
		
	if port_line_edit.text.is_empty():
		port = port_line_edit.placeholder_text
	else:
		port = port_line_edit.text
		multiplayer_info.last_used_port = port
	
	if not ip.is_valid_ip_address():
		print("Invalid IP address")
		return false

	if not port.is_valid_int():
		print("Invalid port")
		return false
	
	multiplayer_info.write_info()
	
	return true


func get_local_ip():
	var addresses = IP.get_local_addresses()
	for ip in addresses:
		if ip == "127.0.0.1" or ip.begins_with("169.254") or ":" in ip:
			continue
		if ip.begins_with("192.168.") or ip.begins_with("10."):
			return ip
	return "No IP found"


func _on_host_button_pressed():
	if not validate_ip_and_port():
		return
		
	save_settings()
	
	NetworkManager.host_game(int(port))
	
	host_join_audio_stream_player.play()
	
	host_button.visible = false
	join_button.visible = false
	#relocator.visible = true
	start_button.visible = true


func _on_join_button_pressed():
	if not validate_ip_and_port():
		return
		
	retry_count = 0
	is_attempting_connection = false
	
	host_join_audio_stream_player.play()
	
	host_button.visible = false
	join_button.visible = false
	
	attempt_connection()


func attempt_connection():
	if is_attempting_connection: return
	is_attempting_connection = true
	
	print("Attempting to connect... Try #", retry_count + 1)
	NetworkManager.join_game(ip, int(port))
	
	await get_tree().create_timer(5.0).timeout
	
	if multiplayer.multiplayer_peer == null or multiplayer.get_unique_id() == 0:
		_on_connection_failed()


@rpc("authority", "call_remote", "reliable")
func sync_game_settings(tracks: int, rounds: int, multiplier: float):
	GameManager.total_tracks = tracks
	GameManager.total_rounds = rounds
	GameManager.cost_multiplier = multiplier


func _on_connection_failed():
	if not is_attempting_connection: return 
	is_attempting_connection = false
	
	if retry_count < MAX_RETRIES - 1:
		retry_count += 1
		print("Connection failed. Retrying in 2 seconds...")
		
		# clean up failed peer before trying again
		multiplayer.multiplayer_peer = null
		
		await get_tree().create_timer(2.0).timeout
		attempt_connection()
	else:
		print("All retry attempts failed.")
		reset_network_buttons()


func _on_connection_success():
	print("Successfully connected!")
	is_attempting_connection = false
	retry_count = 0 # reset counter


func reset_network_buttons():
	host_button.visible = true
	join_button.visible = true
	multiplayer.multiplayer_peer = null


func _on_start_button_pressed():
	sync_game_settings.rpc(
		GameManager.total_tracks, 
		GameManager.total_rounds, 
		GameManager.cost_multiplier
	)
	
	NetworkManager.start_game_for_all()
	
	start_audio_stream_player.play()


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
	SceneTransition.reveal_hide_transition([settings], [non_settings, settings_area_2d])

	
func _on_open_book_clicked() -> void:
	save_settings()
	SceneTransition.reveal_hide_transition([non_settings, settings_area_2d], [settings])


func _on_player_name_line_edit_text_changed(new_text: String) -> void:
	NetworkManager.local_username = new_text


func _on_check_button_toggled(toggled_on: bool) -> void:
	if toggled_on:
		ip_line_edit.placeholder_text = get_local_ip()
	else:
		ip_line_edit.placeholder_text = multiplayer_info.last_used_ip
