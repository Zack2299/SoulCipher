extends Node

@export var scene_to_switch_to: PackedScene
@export var room_name_to_switch_to: String
@export var set_parent_invisible: bool = true 
# ^ for when relocator is not in a room (the previous room relocator in world -- never want to set world invisible)

@onready var sprite_2d: Sprite2D = $Sprite2D
@onready var area_2d: Area2D = $Area2D
@onready var clickable_area: Node = $ClickableArea

var transition_time_with_buffer = 1.25


func _ready() -> void:
	clickable_area.mouse_clicked.connect(_on_clickable_area_mouse_clicked)
	clickable_area.mouse_entered_clickable_area.connect\
		(_on_clickable_area_mouse_entered_clickable_area)
	clickable_area.mouse_exited_clickable_area.connect\
		(_on_clickable_area_mouse_exited_clickable_area)	
var relocator_hovered = false


func _on_clickable_area_mouse_entered_clickable_area() -> void:
	sprite_2d.frame = 1
	relocator_hovered = true


func _on_clickable_area_mouse_exited_clickable_area() -> void:
	sprite_2d.frame = 0
	relocator_hovered = false


func _on_clickable_area_mouse_clicked() -> void:
	Cursor.is_hovering = false
	area_2d.visible = false
	spawn_and_switch()
	await get_tree().create_timer(transition_time_with_buffer).timeout
	area_2d.visible = true


func spawn_and_switch() -> void:
	# completely changes scene (so destroys current scene and switches)
	# (for titlescreen)
	if scene_to_switch_to:
		SceneTransition.change_scene_packed(scene_to_switch_to)
	elif room_name_to_switch_to != "": # otherwise just change visibility rather than destroying
	
		if set_parent_invisible:
			var target_room = get_tree().root.find_child(room_name_to_switch_to, true, false)
			var room_to_set_invisible = get_parent()
			SceneTransition.change_scene_room_name(room_name_to_switch_to, target_room, room_to_set_invisible, set_parent_invisible)
		else:
			room_name_to_switch_to = SceneTransition.room_history_queue.pop_front()
			var target_room = get_tree().root.find_child(room_name_to_switch_to, true, false)
			var target_invis_room = get_tree().root.find_child(SceneTransition.current_room, true, false)
			SceneTransition.change_scene_room_name(room_name_to_switch_to, target_room, target_invis_room, set_parent_invisible)
		
		# tell everyone where we are headed
		var my_id = multiplayer.get_unique_id()
		var my_data_node = get_node("/root/World/PlayersData/" + str(my_id))
		if my_data_node:
			my_data_node.change_room.rpc(room_name_to_switch_to)
		
	else:
		print("Nothing assigned!")
