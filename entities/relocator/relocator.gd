extends Node

enum RelocatorSide { LEFT, RIGHT, NEUTRAL }
@export var relocator_side: RelocatorSide = RelocatorSide.NEUTRAL
@export var scene_to_switch_to: PackedScene
@export var room_name_to_switch_to: String
@export var set_parent_invisible: bool = true 
@export var is_going_back: bool = false
# ^ for when relocator is not in a room (the previous room relocator in world -- never want to set world invisible)
var relocator_index: int

@onready var sprite_2d: Sprite2D = $Sprite2D
@onready var area_2d: Area2D = $Area2D
@onready var clickable_area: Node = $ClickableArea
@onready var exit_audio_stream_player: AudioStreamPlayer = $ExitAudioStreamPlayer
@onready var click_audio_stream_player: AudioStreamPlayer = $ClickAudioStreamPlayer

var transition_time_with_buffer = 1.1


func _ready() -> void:
	if is_going_back:
		sprite_2d.texture = preload("uid://cmnkt2q6uyoxj")
		click_audio_stream_player.stream = preload("uid://c6dfmgtico5f0")
	
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
	if room_name_to_switch_to == "" and not scene_to_switch_to:
		print("Relocator clicked, but no target room assigned by RoomManager!")
		return
		
	Cursor.is_hovering = false
	area_2d.visible = false
	spawn_and_switch()
	await get_tree().create_timer(transition_time_with_buffer).timeout
	area_2d.visible = true


func spawn_and_switch() -> void:
	if scene_to_switch_to:
		SceneTransition.change_scene_packed(scene_to_switch_to)
		return

	var target_name = room_name_to_switch_to
	#var is_going_back = is_fixed_navigation
	var back_button = get_node_or_null("/root/World/PreviousRoomRelocator")
	
	if is_going_back:
		if SceneTransition.room_history_queue.is_empty(): return
		
		# capture current state
		var leaving_room_name = SceneTransition.current_room
		
		# pop the target
		var history_data = SceneTransition.room_history_queue.pop_back()
		target_name = history_data["name"]
		var return_door_index = history_data["door_index"]
		
		# FIXED REVOLVING LOGIC
		# only swap if we are going to the staircase OR leaving it, 
		# AND there's nothing else left in the history queue.
		if SceneTransition.room_history_queue.is_empty():
			if target_name == "staircase" or leaving_room_name == "staircase":
				var room_node = get_node_or_null("/root/World/RoomManager/" + leaving_room_name)
				var current_exit_idx = 0 
				
				if room_node and "relocators" in room_node:
					for i in range(room_node.relocators.size()):
						if room_node.relocators[i].room_name_to_switch_to == target_name:
							current_exit_idx = i
							break
				
				# push back the room we just left to keep the button active at the staircase
				SceneTransition.room_history_queue.push_back({
					"name": leaving_room_name,
					"door_index": current_exit_idx
				})

		# standard navigation
		var target_room = get_node("/root/World/RoomManager/" + target_name)
		var room_to_hide = get_node("/root/World/RoomManager/" + SceneTransition.current_room)
		
		# safety check for blank room
		if not target_room:
			print("CRITICAL: Target room ", target_name, " not found in RoomManager!")
			return

		# change locally and rpc the data
		var my_id = multiplayer.get_unique_id()
		# find the player data node named after ID
		var my_data = get_tree().root.find_child(str(my_id), true, false)
		if my_data:
			my_data.change_room.rpc(target_name)
		SceneTransition.change_scene_room_name(target_name, target_room, room_to_hide, false)
		
		# visuals and camera
		if target_room and "relocators" in target_room:
			var back_door = target_room.relocators[return_door_index]
			var center = target_room.global_position 
			await get_tree().create_timer(1.0/3.0).timeout
			
			if back_button:
				back_button.visible = !SceneTransition.room_history_queue.is_empty()
			SceneTransition.zoom_and_recenter(back_door.global_position, center)
			
			var world = get_node_or_null("/root/World")
			if world: world.refresh_all_ui_visibility()
			 
	else:
		# FORWARD MOVEMENT RESET
		if SceneTransition.current_room == "staircase":
			SceneTransition.room_history_queue.clear()

		var target_room = get_node("/root/World/RoomManager/" + target_name)
		var room_to_hide = get_parent()

		# change locally and rpc the data
		var my_id = multiplayer.get_unique_id()
		# find the player data node named after ID
		var my_data = get_tree().root.find_child(str(my_id), true, false)
		if my_data:
			my_data.change_room.rpc(target_name)
		SceneTransition.change_scene_room_name(target_name, target_room, room_to_hide, true, relocator_index)
		
		await get_tree().create_timer(1.0/3.0).timeout
		if back_button:
			back_button.visible = true
			
		var world = get_node_or_null("/root/World")
		if world: world.refresh_all_ui_visibility()
