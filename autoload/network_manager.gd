extends Node

var peer = ENetMultiplayerPeer.new()
var player_info: Dictionary = {} 
var local_username: String = "Player"
var connected_ids: Array[int]

var current_world_node = null 

func _ready():
	multiplayer.peer_connected.connect(_on_player_connected)
	multiplayer.peer_disconnected.connect(_on_player_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)

func host_game(port: int):
	var error = peer.create_server(port)
	if error != OK:
		print("Failed to host: ", error)
		return
		
	multiplayer.multiplayer_peer = peer
	connected_ids.append(1)
	register_player_info(1, local_username)
	print("Server started on port %d" % port)

func join_game(ip_address: String, port: int):
	var error = peer.create_client(ip_address, port)
	if error != OK:
		print("Failed to join: ", error)
		return
		
	multiplayer.multiplayer_peer = peer

func _on_player_connected(id: int):
	print("Player connected: %d" % id)
	if not connected_ids.has(id):
		connected_ids.append(id)
	
	# IF THE GAME IS ALREADY RUNNING:
	# tell the world to spawn a data node for this new person
	if multiplayer.is_server() and current_world_node != null:
		current_world_node.spawn_player(id)

func _on_player_disconnected(id: int):
	connected_ids.erase(id)
	print("Player disconnected: %d" % id)

func _on_connected_to_server():
	var id = multiplayer.get_unique_id()
	register_player_info.rpc(id, local_username)

@rpc("any_peer", "reliable")
func register_player_info(id: int, p_name: String):
	if multiplayer.is_server():
		player_info[id] = p_name
		# send updated dictionary to everyone
		update_player_list.rpc(player_info)

@rpc("authority", "reliable")
func update_player_list(new_info: Dictionary):
	player_info = new_info
	print("Player list updated: ", player_info)

func start_game_for_all():
	if multiplayer.is_server():
		rpc_load_game_scene.rpc()

@rpc("any_peer", "call_local", "reliable")
func rpc_load_game_scene():
	SceneTransition.change_scene_packed(load("uid://i0m57dlbwrbl"))
