extends Node

signal update_player_ui(id: int, avatar: int)

@export var player_id: int 
@export var player_name: String = "Player"
@export var avatar_id: int = 0

signal room_changed(new_room: String)

# track the room location for this specific player
var current_room: String = "staircase" 

var broadcast_count: int = 0


func _ready():
	add_to_group("players")
	print("NODE ONLINE: ", get_path(), " | Peer ID: ", multiplayer.get_unique_id())
	
	if multiplayer.is_server():
		broadcast_loop()


func broadcast_loop():
	if not is_inside_tree() or broadcast_count >= 5: 
		return
	
	var info = NetworkManager.player_info.get(player_id)
	if info:
		self.player_name = info["name"]
		self.avatar_id = info["avatar"]
		sync_data_to_clients.rpc(player_id, info["name"], info["avatar"])
	
	broadcast_count += 1
	
	if broadcast_count < 5:
		get_tree().create_timer(0.1).timeout.connect(broadcast_loop)


@rpc("authority", "call_local", "reliable")
func sync_data_to_clients(id_from_server: int, new_name: String, new_avatar: int):
	self.player_id = id_from_server
	self.player_name = new_name
	self.avatar_id = new_avatar
	update_player_ui.emit(self.player_id, self.avatar_id)


@rpc("any_peer", "call_local", "reliable")
func change_room(new_room_name: String):
	if multiplayer.get_remote_sender_id() == player_id or multiplayer.is_server():
		current_room = new_room_name
		room_changed.emit(current_room) # Tell the UI the location updated
