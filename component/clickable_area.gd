extends Node

@export var area_2d: Area2D
signal mouse_entered_clickable_area
signal mouse_exited_clickable_area

func _ready() -> void:
	area_2d.input_pickable = true
	area_2d.mouse_entered.connect(_on_mouse_entered)
	area_2d.mouse_exited.connect(_on_mouse_exited)


func _on_mouse_entered():
	Cursor.is_hovering = true
	mouse_entered_clickable_area.emit()


func _on_mouse_exited():
	Cursor.is_hovering = false
	mouse_exited_clickable_area.emit()
