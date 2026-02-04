extends Node2D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	visibility_changed.connect(_on_visibility_changed)


func _on_visibility_changed():
	if visible:
		show_cards()


func show_cards():
	pass
