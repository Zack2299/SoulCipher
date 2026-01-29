extends Node2D

@onready var rooms_container = $Rooms
@onready var previous_room_relocator: Node2D = $PreviousRoomRelocator

@export_dir var rooms_file_path: String = "res://rooms/"

var loaded_scenes: Array[PackedScene] = []


func _ready() -> void:
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
			rooms_container.add_child(room_instance)
			
			room_instance.name = scene.resource_path.get_file().get_basename()
			print(room_instance.name)
			if room_instance.name == "staircase":
				room_instance.visible = true
			else:
				room_instance.visible = false


func _process(delta: float) -> void:
	previous_room_relocator.room_name_to_switch_to = SceneTransition.previous_room
	
	if SceneTransition.current_room == "staircase":
		previous_room_relocator.visible = false
	else:
		previous_room_relocator.visible = true
