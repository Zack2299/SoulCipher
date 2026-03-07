extends Node

var peer = ENetMultiplayerPeer.new()
var player_info: Dictionary = {} 
var local_username: String = "Player"
var local_avatar_id: int = 0
var connected_ids: Array[int] = []

var world_node = null 


func _ready():
	multiplayer.peer_connected.connect(_on_player_connected)
	multiplayer.peer_disconnected.connect(_on_player_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)

	local_username = "Player"
	local_avatar_id = randi_range(0, 7)


func host_game(port: int):
	var error = peer.create_server(port)
	if error != OK:
		print("Failed to host: ", error)
		return
		
	multiplayer.multiplayer_peer = peer
	connected_ids.append(1)
	var info = {"name": local_username, "avatar": local_avatar_id}
	register_player_info(1, info)
	print("Server started on port %d" % port)


func join_game(ip_address: String, port: int):
	var error = peer.create_client(ip_address, port)
	if error != OK:
		print("Failed to join: ", error)
		return
		
	multiplayer.multiplayer_peer = peer


func _on_player_connected(id: int):
	print("Player connected: %d" % id)
	if multiplayer.is_server():
		if not connected_ids.has(id):
			connected_ids.append(id)
		
		# Sync the list to everyone and spawn the player if the world is active
		sync_connected_ids.rpc(connected_ids)
		if world_node != null:
			world_node.spawn_player(id)


func _on_player_disconnected(id: int):
	print("Player disconnected: %d" % id)
	
	if multiplayer.is_server():
		connected_ids.erase(id)
		player_info.erase(id)
		
		# tell clients to update
		sync_connected_ids.rpc(connected_ids)
		update_player_list.rpc(player_info)
		
		rpc("rpc_despawn_player_everywhere", id)


@rpc("authority", "call_local", "reliable")
func rpc_despawn_player_everywhere(id: int):
	if world_node:
		world_node.despawn_player(id)


#@rpc("authority", "call_local", "reliable")
#func refresh_ui_on_disconnect():
	#if GameManager.world_node:
		#GameManager.world_node.rebuild_player_ui()


func _on_connected_to_server():
	var id = multiplayer.get_unique_id()
	var my_data = {
		"name": local_username,
		"avatar": local_avatar_id
	}
	register_player_info.rpc(id, my_data)


@rpc("any_peer", "reliable")
func register_player_info(id: int, info: Dictionary):
	if multiplayer.is_server():
		player_info[id] = info
		update_player_list.rpc(player_info)
		sync_connected_ids.rpc(connected_ids)


@rpc("authority", "call_local", "reliable")
func update_player_list(new_info: Dictionary):
	player_info = new_info
	print("Global Player Info Updated: ", player_info)


@rpc("authority", "call_local", "reliable")
func sync_connected_ids(server_list: Array):
	connected_ids = Array(server_list, TYPE_INT, &"", null)
	# If the world is already loaded, ensure all peers in the list are spawned
	if world_node:
		for id in connected_ids:
			world_node.spawn_player(id)


func start_game_for_all():
	if multiplayer.is_server():
		rpc_load_game_scene_first_half.rpc()


# the first function is the complete function, for late players and resets
# the next 2 are for when we first start, where there may be a delay so we need
# the screen to stay black for longer
@rpc("any_peer", "call_local", "reliable")
func rpc_load_game_scene():
	SceneTransition.change_scene_packed(load("uid://i0m57dlbwrbl"), 1.0)


@rpc("any_peer", "call_local", "reliable")
func rpc_load_game_scene_first_half():
	SceneTransition.change_scene_packed_first_half(load("uid://i0m57dlbwrbl"), 1.0)


@rpc("any_peer", "call_local", "reliable")
func rpc_load_game_scene_second_half():
	SceneTransition.change_scene_packed_second_half(load("uid://i0m57dlbwrbl"), 1.0)
