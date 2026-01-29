extends Node2D


func generate_mansion(rooms: Array[Node]):
	if not multiplayer.is_server():
		return

	var layout_map = {} # dictionary mapping self name to array of other room 
	# names (relocator 1 is first spot, relocator 2 2nd, etc)
	
