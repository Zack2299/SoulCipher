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

				var number_string = child.name.replace("Relocator", "")

				var id = 0 # Default for the first one
				if number_string != "" and !child.name.contains("room"):
					id = int(number_string) - 1
					
				if "relocator_index" in child:
					child.relocator_index = id
			
	relocators.sort_custom(func(a, b): return a.relocator_index < b.relocator_index)
