# player_container.gd
extends CenterContainer

@onready var sprite_2d: Sprite2D = $Sprite2D
var data_node: Node = null

func setup(p_data: Node):
	if not is_node_ready():
		await ready 
	
	data_node = p_data
	if data_node:
		sprite_2d.frame = data_node.avatar_id
		# Listen for when this player changes rooms
		data_node.room_changed.connect(_on_player_room_changed)
		
		add_to_group("player_uis")
		
		# Initial visibility check
		update_visibility()

func _on_player_room_changed(_new_room: String):
	update_visibility()

func update_visibility():
	if not data_node: return
	
	# 1. Find the local player's data to see where WE are
	var my_id = multiplayer.get_unique_id()
	var my_data = get_node_or_null("/root/World/PlayersData/" + str(my_id))
	
	if my_data:
		# 2. Only show if this player's room matches our room
		self.visible = (data_node.current_room == my_data.current_room)
	else:
		# Safety: if we can't find ourselves yet, just show everyone
		self.visible = true
