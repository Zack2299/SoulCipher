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


#func spawn_player(id: int):
	## SAFETY: If the UI isn't ready yet, wait one frame
	#if not is_inside_tree() or player_ui_hbox == null:
		#await get_tree().process_frame
		#spawn_player(id) # Retry
		#return
#
	#if players_data.has_node(str(id)): return
	#
	#var p_data = preload("res://manager/player_data.tscn").instantiate()
	#p_data.name = str(id)
	#p_data.player_id = id
	#
	#var info = NetworkManager.player_info.get(id, {"name": "Guest", "avatar": 0})
	#p_data.player_name = info["name"]
	#p_data.avatar_id = info["avatar"]
	#
	#players_data.add_child(p_data, true)
#
	## Create the UI Card
	#var p_ui = preload("res://entities/player_container/player_container.tscn").instantiate()
	#p_ui.name = "UI_" + str(id) 
	#
	## Add child before accessing its internal nodes
	#player_ui_hbox.add_child(p_ui)
	#
	## Initial UI Setup
	#p_ui.setup(p_data)

func spawn_player(id: int):
	if players_data.has_node(str(id)): return
	
	var p_data = preload("res://manager/player_data.tscn").instantiate()
	p_data.name = str(id)
	p_data.player_id = id
	
	# Only the server should pull from the NetworkManager's dictionary
	if multiplayer.is_server():
		var info = NetworkManager.player_info.get(id, {"name": "Guest", "avatar": 0})
		p_data.player_name = info["name"]
		p_data.avatar_id = info["avatar"]
	
	players_data.add_child(p_data, true)

	var p_ui = preload("res://entities/player_container/player_container.tscn").instantiate()
	p_ui.name = "UI_" + str(id) 
	player_ui_hbox.add_child(p_ui)
	p_ui.setup(p_data)
