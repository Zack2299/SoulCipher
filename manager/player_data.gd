extends Node

signal update_player_ui(id: int, avatar: int)

@export var player_id: int # This MUST be set by world.gd before add_child
@export var player_name: String = "Player"
@export var avatar_id: int = 0

func _ready():
	add_to_group("players")
	# This will reveal the truth in the console
	print("NODE ONLINE: ", get_path(), " | Peer ID: ", multiplayer.get_unique_id())
	
	if multiplayer.is_server():
		broadcast_loop()

func broadcast_loop():
	# Keep the hammer swinging every 1 second
	get_tree().create_timer(1.0).timeout.connect(broadcast_loop)
	
	# Get info from the NetworkManager source of truth
	var info = NetworkManager.player_info.get(player_id)
	
	if info:
		# Update server's local variables
		self.player_name = info["name"]
		self.avatar_id = info["avatar"]
		
		# Hammer every client (including server) with the data AND the ID
		sync_data_to_clients.rpc(player_id, info["name"], info["avatar"])

@rpc("authority", "call_local", "reliable")
func sync_data_to_clients(id_from_server: int, new_name: String, new_avatar: int):
	# Update local variables
	self.player_id = id_from_server
	self.player_name = new_name
	self.avatar_id = new_avatar
	
	# Tell the World to update the UI using the ID the server just gave us
	update_player_ui.emit(self.player_id, self.avatar_id)
