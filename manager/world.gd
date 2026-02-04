class_name World
extends Node2D

@onready var room_manager: Node2D = $RoomManager
@onready var previous_room_relocator: Node2D = $PreviousRoomRelocator
@onready var players_data: Node2D = $PlayersData
@onready var player_ui_hbox: HBoxContainer = $PlayerUI/PlayerUIHbox

@onready var ghost_ui: CanvasLayer = $GhostUI
@onready var player_ui: CanvasLayer = $PlayerUI
@onready var shop: Node2D = $Shop
@onready var card_select: Node2D = $CardSelect

@export_dir var rooms_file_path: String = "res://rooms/"

var loaded_scenes: Array[PackedScene] = []
var rooms_array: Array[Node] = []
var havent_explored_rooms = true


# --- DEBUG ---
signal ghost_turn_over
signal player_turn_over

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("one"):
		request_phase_change.rpc("ghost")
	elif event.is_action_pressed("two"):
		request_phase_change.rpc("player")


@rpc("any_peer", "call_local", "reliable")
func request_phase_change(type: String):
	if not multiplayer.is_server():
		return
		
	if type == "ghost":
		ghost_turn_over.emit()
	elif type == "player":
		player_turn_over.emit()
# --- DEBUG ---


func _ready() -> void:
	NetworkManager.world_node = self
	GameManager.world_node = self
	
	load_scenes_from_folder()
	spawn_rooms_to_world(loaded_scenes)
	
	# small delay ensures the sync_connected_ids RPC has landed on clients
	await get_tree().process_frame
	
	print("World ready. Spawning connected players: ", NetworkManager.connected_ids)
	for id in NetworkManager.connected_ids:
		spawn_player(id)
		
	if multiplayer.is_server():
		_server_initialize_match()
		
	card_select.visibility_changed.connect(_on_card_select_visibility_changed)
	shop.visibility_changed.connect(_on_shop_visibility_changed)


func _on_card_select_visibility_changed():
	room_manager.visible = !card_select.visible


func _on_shop_visibility_changed():
	room_manager.visible = !shop.visible


func _server_initialize_match():
	# ensure we have players
	var player_ids = NetworkManager.connected_ids
	if player_ids.is_empty():
		return
	
	var ghost_id = 1 # server is ghost as default
	if GameManager.random_ghost:
		ghost_id = player_ids[randi() % player_ids.size()]
	
	print("SERVER: Match starting. Ghost: ", ghost_id)
	
	# start global game manager state machine
	GameManager.start_match(ghost_id)


func refresh_all_ui_visibility():
	get_tree().call_group("player_uis", "update_visibility")


func load_scenes_from_folder() -> void:
	var dir = DirAccess.open(rooms_file_path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if !dir.current_is_dir() and file_name.ends_with(".tscn"):
				var full_path = rooms_file_path + "/" + file_name
				var scene_resource = load(full_path)
				if scene_resource is PackedScene:
					loaded_scenes.append(scene_resource)
			file_name = dir.get_next()
	else:
		print("Couldn't access path.")


func spawn_rooms_to_world(scenes_array: Array[PackedScene]) -> void:
	for scene in scenes_array:
		if scene:
			var room_instance = scene.instantiate()
			room_instance.name = scene.resource_path.get_file().get_basename()
			room_manager.add_child(room_instance)
			rooms_array.push_back(room_instance)
			
			if room_instance.name == "staircase":
				room_instance.visible = true
			else:
				room_instance.visible = false

	if multiplayer.is_server():
		get_tree().create_timer(0.5).timeout.connect(func(): room_manager.generate_mansion(rooms_array))


func _process(_delta: float) -> void:
	if SceneTransition.previous_room != "":
		previous_room_relocator.room_name_to_switch_to = SceneTransition.previous_room


func spawn_player(id: int):
	if players_data.has_node(str(id)): 
		return
	
	# 1. Spawn UI
	var p_ui = preload("res://entities/player_container/player_container.tscn").instantiate()
	p_ui.name = "UI_" + str(id) 
	player_ui_hbox.add_child(p_ui)
	
	# 2. Setup Data Node
	var p_data = preload("res://manager/player_data.tscn").instantiate()
	p_data.name = str(id) # Name matches peer ID exactly
	p_data.player_id = id
	
	if multiplayer.is_server():
		var info = NetworkManager.player_info.get(id, {"name": "Guest", "avatar": 0})
		p_data.player_name = info["name"]
		p_data.avatar_id = info["avatar"]
	
	p_data.update_player_ui.connect(_on_update_player_ui)
	
	# 3. Add to tree (without the 'true' flag to keep path predictable)
	players_data.add_child(p_data)
	
	# 4. Initialize UI
	p_ui.setup(p_data)

func _on_update_player_ui(id: int, avatar_index: int):
	var ui_node_name = "UI_" + str(id)
	var ui_node = player_ui_hbox.get_node_or_null(ui_node_name)
	
	if ui_node and ui_node.is_inside_tree():
		if ui_node.sprite_2d:
			ui_node.sprite_2d.frame = avatar_index
