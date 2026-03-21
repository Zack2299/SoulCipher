extends PanelContainer

@onready var label: Label = $MarginContainer/Label
@onready var animation_player: AnimationPlayer = $AnimationPlayer

func set_message(text: String, color: Color = Color.WHITE):
	label.text = text
	label.modulate = color
	await animation_player.animation_finished
	queue_free()
