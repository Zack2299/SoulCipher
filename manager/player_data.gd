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
	if not is_inside_tree(): return
	
	# 1. ONLY the server runs the logic to send data
	if multiplayer.is_server():
		var info = NetworkManager.player_info.get(player_id)
		if info:
			# Server updates its own variables
			self.player_name = info["name"]
			self.avatar_id = info["avatar"]
			# Server forces every client to update
			sync_data_to_clients.rpc(player_id, info["name"], info["avatar"])
	
	# 2. Re-run the loop (on both, though only server does work)
	get_tree().create_timer(1.0).timeout.connect(broadcast_loop)


@rpc("authority", "call_local", "reliable")
func sync_data_to_clients(id_from_server: int, new_name: String, new_avatar: int):
	self.player_id = id_from_server
	self.player_name = new_name
	self.avatar_id = new_avatar
	
	# Signal the world to update the UI
	update_player_ui.emit(self.player_id, self.avatar_id)
