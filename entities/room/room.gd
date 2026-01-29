class_name Room
extends Node2D

var relocators: Array = []


# Inside room.gd
func _ready() -> void:
	for child in get_children():
		if child.is_in_group("relocator_group"):
			# Check if it has the variable AND if that variable is false
			if !child.get("is_fixed_navigation"):
				relocators.append(child)
