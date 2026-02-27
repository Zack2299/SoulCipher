extends Node2D

@onready var restart_game_button: Button = $RestartGameButton

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	restart_game_button.visible = multiplayer.is_server()
