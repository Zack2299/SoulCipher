extends Node2D

var mansion_layout: Dictionary = {}

func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)

func _on_peer_connected(id: int):
	if multiplayer.is_server() and not mansion_layout.is_empty():
		sync_mansion_layout.rpc_id(id, mansion_layout)

func generate_mansion(rooms: Array[Node]):
	if not multiplayer.is_server(): return
	await get_tree().process_frame

	var layout_data = {} 

	# balanced distribution by hubs
	var full_pool = rooms.filter(func(r): return r.name != "staircase")
	full_pool.sort_custom(func(a, b): return a.relocators.size() > b.relocators.size())
	
	var left_pool = []
	var right_pool = []
	for i in range(full_pool.size()):
		if i % 2 == 0: left_pool.append(full_pool[i])
		else: right_pool.append(full_pool[i])
	
	left_pool.shuffle()
	right_pool.shuffle()

	# initialize empty data structure
	for room in rooms:
		layout_data[room.name] = []
		for i in range(room.relocators.size()):
			layout_data[room.name].append("")

	# build the wings
	var reached_left = _build_tree_wing("staircase", 0, left_pool, layout_data, rooms, 0)
	var reached_right = _build_tree_wing("staircase", 1, right_pool, layout_data, rooms, 1)

	# add Hub-to-Staircase Return Shortcuts
	_add_staircase_return_shortcut(reached_left, layout_data, rooms)
	_add_staircase_return_shortcut(reached_right, layout_data, rooms)

	# create Safe Internal Loops (Using remaining empty doors)
	_create_safe_wing_loops(reached_left, layout_data)
	_create_safe_wing_loops(reached_right, layout_data)

	mansion_layout = layout_data
	
	# REACHABILITY REPORT
	var all_reachable = ["staircase"] + reached_left + reached_right
	_print_mansion_report(layout_data, rooms, all_reachable)
	
	sync_mansion_layout.rpc(layout_data)

func _build_tree_wing(root_name: String, root_index: int, wing_pool: Array, layout: Dictionary, all_rooms: Array, side_filter: int) -> Array:
	if wing_pool.is_empty(): return []
	var connected = [root_name]
	var reached = []
	var remaining = wing_pool.duplicate()
	remaining.sort_custom(func(a, b): return a.relocators.size() > b.relocators.size())

	# seed the wing from the staircase
	var first = remaining.pop_front()
	layout[root_name][root_index] = first.name
	connected.append(first.name)
	reached.append(first.name)

	while not remaining.is_empty():
		var new_room = remaining.pop_front()
		var success = false
		for parent in connected:
			var parent_node = _get_room_by_name(parent, all_rooms)
			if not parent_node: continue
			
			for i in range(layout[parent].size()):
				if layout[parent][i] == "":
					var door = parent_node.relocators[i]
					# 0=Left, 1=Right, 2=Neutral
					if door.relocator_side == side_filter or door.relocator_side == 2:
						layout[parent][i] = new_room.name
						connected.append(new_room.name)
						reached.append(new_room.name)
						success = true
						break
			if success: break
	return reached

func _add_staircase_return_shortcut(wing_names: Array, layout: Dictionary, all_rooms: Array):
	if wing_names.is_empty(): return
	var candidates = []
	for r_name in wing_names:
		var node = _get_room_by_name(r_name, all_rooms)
		if node and layout[r_name].count("") > 0: candidates.append(node)
	if candidates.is_empty(): return
	
	# select the room with the most total doors to be the return-hub
	candidates.sort_custom(func(a, b): return a.relocators.size() > b.relocators.size())
	var hub_room = candidates[0]
	for i in range(layout[hub_room.name].size()):
		if layout[hub_room.name][i] == "":
			layout[hub_room.name][i] = "staircase"
			break

func _create_safe_wing_loops(wing_names: Array, layout: Dictionary):
	for r_name in wing_names:
		for i in range(layout[r_name].size()):
			if layout[r_name][i] == "":
				var potential_targets = wing_names.filter(func(n): 
					return n != r_name and not n in layout[r_name]
				)
				if not potential_targets.is_empty() and randf() > 0.4:
					layout[r_name][i] = potential_targets.pick_random()

func _get_room_by_name(r_name: String, rooms: Array) -> Node:
	for r in rooms:
		if r.name == r_name: return r
	return null

# orphan detection
func _print_mansion_report(data: Dictionary, all_rooms: Array, reachable: Array):
	print("\n" + "=".repeat(50))
	print("MANSION ARCHITECTURE REPORT")
	print("=".repeat(50))
	
	var all_room_names = all_rooms.map(func(r): return r.name)
	var orphaned: Array[String] = []
	for name in all_room_names:
		if not name in reachable: orphaned.append(name)
		
	get_parent().orphaned_room_names = orphaned.duplicate()
	
	if orphaned.is_empty():
		print("All rooms are connected to the staircase")
	else:
		print("THE FOLLOWING ROOMS ARE UNREACHABLE")
		print("   (These rooms will never spawn in the game layout)")
		for name in orphaned: print("   - " + name)

	print("-".repeat(50))
	for room in data:
		print("[ %-12s ] Exits: %s" % [room.to_upper(), str(data[room])])
	print("=".repeat(50) + "\n")

@rpc("authority", "call_local", "reliable")
func sync_mansion_layout(layout_data: Dictionary):
	mansion_layout = layout_data
	for room_name in layout_data:
		var room_node = get_node_or_null(NodePath(room_name))
		if room_node and "relocators" in room_node:
			var targets = layout_data[room_name]
			for i in range(targets.size()):
				if i < room_node.relocators.size():
					var reloc = room_node.relocators[i]
					if not reloc.get("is_fixed_navigation"):
						reloc.room_name_to_switch_to = targets[i]
