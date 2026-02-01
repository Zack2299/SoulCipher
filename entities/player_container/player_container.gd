extends CenterContainer

@onready var sprite_2d: Sprite2D = $Sprite2D

func setup(p_data: Node):
	# Initial frame set for the server/host 
	if p_data and sprite_2d:
		sprite_2d.frame = p_data.avatar_id
