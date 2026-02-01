extends Node2D

#@onready var rooms_container = $Rooms
@onready var room_manager: Node2D = $RoomManager
@onready var previous_room_relocator: Node2D = $PreviousRoomRelocator
@onready var players_data: Node2D = $PlayersData
@onready var player_ui_hbox: HBoxContainer = $CanvasLayer/PlayerUIHbox

@export_dir var rooms_file_path: String = "res://rooms/"

var loaded_scenes: Array[PackedScene] = []
var rooms_array: Array[Node] = []

var havent_explored_rooms = true


func _ready() -> void:
	NetworkManager.current_world_node = self
	load_scenes_from_folder()
	spawn_rooms_to_world(loaded_scenes)
	
	if multiplayer.is_server():
		print("Server is spawning existing players...")
		for id in NetworkManager.connected_ids:
			spawn_player(id)


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
					print("Loaded scene: ", file_name)
			
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
			
			print(room_instance.name)
			if room_instance.name == "staircase":
				room_instance.visible = true
			else:
				room_instance.visible = false

	if multiplayer.is_server():
		# give the clients a moment to finish their own loop before sending the map
		get_tree().create_timer(0.5).timeout.connect(func(): room_manager.generate_mansion(rooms_array))


func _process(_delta: float) -> void:
	previous_room_relocator.room_name_to_switch_to = SceneTransition.previous_room


func spawn_player(id: int):
	if players_data.has_node(str(id)): return
	
	var p_data = preload("res://manager/player_data.tscn").instantiate()
	
	# 1. SET THE DATA FIRST (while it's still just an object in memory)
	p_data.name = str(id)
	p_data.player_id = id
	
	if multiplayer.is_server():
		var info = NetworkManager.player_info.get(id, {"name": "Guest", "avatar": 0})
		p_data.player_name = info["name"]
		p_data.avatar_id = info["avatar"] # Now the hammer starts with the RIGHT number
	
	# 2. CONNECT SIGNAL
	p_data.update_player_ui.connect(_on_update_player_ui)
	
	# 3. ADD TO TREE (This triggers _ready() and the Hammer loop)
	players_data.add_child(p_data, true)

	# 4. SPAWN UI
	var p_ui = preload("res://entities/player_container/player_container.tscn").instantiate()
	p_ui.name = "UI_" + str(id) 
	player_ui_hbox.add_child(p_ui)
	p_ui.setup(p_data)


func _on_update_player_ui(id: int, avatar_index: int):
	# Construct the name (e.g., "UI_1")
	var ui_node_name = "UI_" + str(id)
	var ui_node = player_ui_hbox.get_node_or_null(ui_node_name)
	
	if ui_node:
		if ui_node.sprite_2d:
			ui_node.sprite_2d.frame = avatar_index
			# print("UI Updated for ID: ", id, " to frame: ", avatar_index)
	else:
		# If this prints, your UI naming convention doesn't match
		print("Hammer hit, but couldn't find node: ", ui_node_name)
