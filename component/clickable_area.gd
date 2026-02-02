# ---
# Handles cursor updates and sounds (if available)
# Area2D necessary, audio ca
# ---

extends Node

@export var area_2d: Area2D
@export var enter_audio: AudioStreamPlayer
@export var exit_audio: AudioStreamPlayer
@export var click_audio: AudioStreamPlayer

signal mouse_entered_clickable_area
signal mouse_exited_clickable_area
signal mouse_clicked

var is_locally_hovered: bool = false


func _ready() -> void:
	if area_2d:
		area_2d.input_pickable = true
		area_2d.mouse_entered.connect(_on_mouse_entered)
		area_2d.mouse_exited.connect(_on_mouse_exited)


func _process(_delta: float) -> void:
	if is_locally_hovered and Input.is_action_just_pressed("click"):
		mouse_clicked.emit()
		
		if click_audio:
			click_audio.play()


func _on_mouse_entered():
	is_locally_hovered = true
	Cursor.is_hovering = true
	mouse_entered_clickable_area.emit()
	
	if enter_audio:
		enter_audio.play()


func _on_mouse_exited():
	is_locally_hovered = false
	Cursor.is_hovering = false
	mouse_exited_clickable_area.emit()
	
	if exit_audio:
		exit_audio.play()
