# ---
# Handles cursor updates and sounds (if available)
# Area2D necessary, audio can be left blank
# ---

extends Node

@export var area_2d: Area2D
@export var enter_audio: AudioStreamPlayer
@export var exit_audio: AudioStreamPlayer
@export var click_audio: AudioStreamPlayer

signal mouse_entered_clickable_area
signal mouse_exited_clickable_area
signal mouse_clicked


func _ready() -> void:
	area_2d.input_pickable = true
	area_2d.mouse_entered.connect(_on_mouse_entered)
	area_2d.mouse_exited.connect(_on_mouse_exited)


func _process(delta: float) -> void:
	if Cursor.is_hovering and Input.is_action_just_pressed("click"):
		mouse_clicked.emit()
		
		if click_audio:
			click_audio.play()


func _on_mouse_entered():
	Cursor.is_hovering = true
	mouse_entered_clickable_area.emit()
	
	if enter_audio:
		enter_audio.play()


func _on_mouse_exited():
	Cursor.is_hovering = false
	mouse_exited_clickable_area.emit()
	
	if exit_audio:
		exit_audio.play()
