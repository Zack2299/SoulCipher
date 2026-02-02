extends CenterContainer

@onready var sprite_2d: Sprite2D = $Sprite2D

# player_container.gd
func setup(p_data: Node):
	if not is_node_ready():
		await ready 
	
	if p_data:
		# We set it once here, but the 'Hammer' signal 
		# from world.gd will keep it updated every second.
		sprite_2d.frame = p_data.avatar_id
