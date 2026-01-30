extends Node2D

#@onready var rooms_container = $Rooms
@onready var room_manager: Node2D = $RoomManager
@onready var previous_room_relocator: Node2D = $PreviousRoomRelocator

@export_dir var rooms_file_path: String = "res://rooms/"

var loaded_scenes: Array[PackedScene] = []
var rooms_array: Array[Node] = []

var havent_explored_rooms = true


func _ready() -> void:
	NetworkManager.current_world_node = self
	load_scenes_from_folder()
	spawn_rooms_to_world(loaded_scenes)


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
		# Give the clients a moment to finish their own loop before sending the map
		get_tree().create_timer(0.5).timeout.connect(func(): room_manager.generate_mansion(rooms_array))

func _process(_delta: float) -> void:
	previous_room_relocator.room_name_to_switch_to = SceneTransition.previous_room
	
	#if SceneTransition.current_room == "staircase" and havent_explored_rooms:
		#previous_room_relocator.visible = false
	#else:
	#if SceneTransition.current_room != "staircase":
		#previous_room_relocator.visible = true
