extends Node

var fullscreen = false


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("press_fullscreen"):
		fullscreen = not fullscreen
		toggle_fullscreen()


func toggle_fullscreen():
	if fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
