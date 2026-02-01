extends CenterContainer

@onready var sprite_2d: Sprite2D = $Sprite2D
@onready var name_label: Label = $Label # Ensure you have a label node

var tracked_data: Node = null

func setup(p_data: Node):
	tracked_data = p_data

func _process(_delta):
	if tracked_data:
		# Update visuals constantly or use a setter in p_data
		sprite_2d.frame = tracked_data.avatar_id
		#name_label.text = tracked_data.player_name
