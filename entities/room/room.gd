class_name Room
extends Node2D

var relocators: Array = []


func _ready() -> void:
	for child in get_children():
		if child.is_in_group("relocator_group"):
			relocators.append(child)
