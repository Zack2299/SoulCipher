extends Node2D

var mansion_layout: Dictionary = {}

const ORPHAN_REJECTION_THRESH = 4


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)


func _on_peer_connected(id: int):
	if multiplayer.is_server() and not mansion_layout.is_empty():
		sync_mansion_layout.rpc_id(id, mansion_layout)


@rpc("any_peer", "call_remote", "reliable")
func request_mansion_sync():
	var sender_id = multiplayer.get_remote_sender_id()
	if multiplayer.is_server() and not mansion_layout.is_empty():
		print("SERVER: Sending mansion layout to player ", sender_id)
		sync_mansion_layout.rpc_id(sender_id, mansion_layout)


func generate_mansion(rooms: Array[Node], attempt: int = 1):
	if not multiplayer.is_server(): return
	await get_tree().process_frame

	var layout_data = {} 
	
	# init empty data structure
	for room in rooms:
		layout_data[room.name] = []
		for i in range(room.relocators.size()):
			layout_data[room.name].append("")
			
	var staircase_node = _get_room_by_name("staircase", rooms)
	var num_wings = staircase_node.relocators.size()

	var crystal_ball_node = _get_room_by_name("crystal_ball_room", rooms)
	var full_pool = rooms.filter(func(r): return r.name != "staircase" and r.name != "crystal_ball_room")
	
	# fuzzy sort
	var room_scores = {}
	for r in full_pool:
		room_scores[r.name] = (r.relocators.size() * 10) + randi_range(0, 40)
	full_pool.sort_custom(func(a, b): return room_scores[a.name] > room_scores[b.name])
	
	# dynamic wing dealing
	var wing_pools = []
	for i in range(num_wings):
		wing_pools.append([])
		
	for i in range(full_pool.size()):
		wing_pools[i % num_wings].append(full_pool[i])

	# build the core mansion
	var all_reached_wings = []
	for i in range(num_wings):
		var side_filter = staircase_node.relocators[i].relocator_side
		var reached = _build_tree_wing("staircase", i, wing_pools[i], layout_data, rooms, side_filter)
		all_reached_wings.append_array(reached)

	#  orphan recovery
	var orphans = full_pool.filter(func(r): return not r.name in all_reached_wings)
	orphans.shuffle()
	
	var connection_points = all_reached_wings.duplicate()
	connection_points.shuffle() # randomize where orphans get attached so it feels natural

	while not orphans.is_empty():
		var orphan = orphans.pop_front()
		var placed = false
		
		for parent_name in connection_points:
			var parent_node = _get_room_by_name(parent_name, rooms)
			if not parent_node: continue
			
			for i in range(layout_data[parent_name].size()):
				if layout_data[parent_name][i] == "":
					# rescue orpan
					layout_data[parent_name][i] = orphan.name
					all_reached_wings.append(orphan.name)
					# orphan can now host other orphans
					connection_points.append(orphan.name) 
					placed = true
					break
			if placed: break
			
		# if orphan truly cannot be placed, it dies
		if not placed:
			print("SYSTEM: Mansion is entirely sealed. Dropping remaining orphans.")
			break

	#_add_staircase_return_shortcuts(all_reached_wings, layout_data, rooms, 1)
	_create_safe_wing_loops(all_reached_wings, layout_data)

	# guarantee crystal ball
	if crystal_ball_node:
		var placed = false
		var search_pool = all_reached_wings.duplicate()
		search_pool.reverse() # check deepest rooms first
		
		for deep_room in search_pool:
			for i in range(layout_data[deep_room].size()):
				if layout_data[deep_room][i] == "":
					layout_data[deep_room][i] = "crystal_ball_room"
					
					all_reached_wings.append("crystal_ball_room")
					placed = true
					break
			if placed: break
			
		# if loops ate every single door, force it onto the deepest room that actually has doors
		if not placed and search_pool.size() > 0:
			var forced_parent = ""
			var door_idx = -1
			
			# find the deepest room that actually has at least one relocator
			for room_name in search_pool:
				if layout_data[room_name].size() > 0:
					forced_parent = room_name
					door_idx = layout_data[room_name].size() - 1
					break
			
			if forced_parent != "":
				var lost_connection = layout_data[forced_parent][door_idx]
				print("CRITICAL: No empty doors left! Forcing Crystal Ball over connection to: ", lost_connection)
				
				layout_data[forced_parent][door_idx] = "crystal_ball_room"
				if layout_data["crystal_ball_room"].size() > 0:
					layout_data["crystal_ball_room"][0] = forced_parent
				all_reached_wings.append("crystal_ball_room")
			else:
				print("FATAL: No rooms in the entire search pool have any doors!")

	# reachability report
	var all_reachable = _get_true_reachable_rooms(layout_data, "staircase")
	
	var orphan_count = rooms.size() - all_reachable.size()
	
	# rejection sampling
	if orphan_count >= ORPHAN_REJECTION_THRESH and attempt < 10:
		print("SYSTEM: Attempt %d failed (%d orphans). Re-rolling mansion layout..." % [attempt, orphan_count])
		generate_mansion(rooms, attempt + 1)
		return
	elif orphan_count >= ORPHAN_REJECTION_THRESH:
		print("SYSTEM: Max retries (10) reached! Forcing acceptance of sub-optimal mansion.")
	else:
		print("SYSTEM: Mansion generation successful on attempt %d!" % attempt)
	
	_print_mansion_report(layout_data, rooms, all_reachable)
	
	var keys_to_remove = []
	for room_name in layout_data:
		if not room_name in all_reachable:
			keys_to_remove.append(room_name)
	for k in keys_to_remove:
		layout_data.erase(k)
		
	mansion_layout = layout_data
	sync_mansion_layout.rpc(layout_data)


func _add_staircase_return_shortcuts(wing_names: Array, layout: Dictionary, all_rooms: Array, target_count: int = 2):
	if wing_names.is_empty(): return
	var candidates = []
	
	for r_name in wing_names:
		var node = _get_room_by_name(r_name, all_rooms)
		if node and layout[r_name].count("") > 0: 
			candidates.append(node)
			
	if candidates.is_empty(): return
	
	# sort to prioritize rooms that still have lots of empty doors
	candidates.sort_custom(func(a, b): return layout[a.name].count("") > layout[b.name].count(""))
	
	var loops_made = 0
	for hub_room in candidates:
		if loops_made >= target_count: break
		
		for i in range(layout[hub_room.name].size()):
			if layout[hub_room.name][i] == "":
				layout[hub_room.name][i] = "staircase"
				loops_made += 1
				break


func _build_tree_wing(root_name: String, root_index: int, wing_pool: Array, layout: Dictionary, all_rooms: Array, side_filter: int) -> Array:
	if wing_pool.is_empty(): return []
	var connected = [root_name]
	var reached = []
	var remaining = wing_pool.duplicate()

	# seed the wing from the staircase
	var first = remaining.pop_front()
	layout[root_name][root_index] = first.name
	connected.append(first.name)
	reached.append(first.name)


	while not remaining.is_empty():
		var new_room = remaining.pop_front()
		var success = false
		
		# shuffle the available parents so it doesn't build a rigid, blocky tree
		var possible_parents = connected.duplicate()
		possible_parents.shuffle()
		
		for parent in possible_parents:
			var parent_node = _get_room_by_name(parent, all_rooms)
			if not parent_node: continue
			
			for i in range(layout[parent].size()):
				if layout[parent][i] == "":
					var door = parent_node.relocators[i]
					# 0=left, 1=right, 2=neutral
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
				if not potential_targets.is_empty() and randf() > 0.7:
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
		
		get_parent().delete_orphaned_rooms(orphaned) # remove orphans on server

	print("-".repeat(50))
	for room in data:
		print("[ %-12s ] Exits: %s" % [room.to_upper(), str(data[room])])
	print("=".repeat(50))
	
	if data.has("crystal_ball_room") or reachable.has("crystal_ball_room"):
		var path_str = _find_path_to_room("staircase", "crystal_ball_room", data)
		print("PATH TO CRYSTAL BALL:")
		print("   " + path_str)
	else:
		print("PATH TO CRYSTAL BALL UNREACHABLE")
		
	print("=".repeat(50) + "\n")


func _find_path_to_room(start_node: String, target_node: String, layout: Dictionary) -> String:
	if start_node == target_node:
		return start_node
		
	var queue = [start_node]
	var visited = {start_node: null} # room_name: [parent_room, exit_index]
	
	# BFS to find shortest path
	while queue.size() > 0:
		var current = queue.pop_front()
		
		if current == target_node:
			break
			
		if not layout.has(current): continue
			
		var exits = layout[current]
		for i in range(exits.size()):
			var neighbor = exits[i]
			if neighbor != "" and not visited.has(neighbor):
				visited[neighbor] = [current, i]
				queue.append(neighbor)
				
	# reconstruct path
	if not visited.has(target_node):
		return "No path found."
		
	var path_segments = []
	var curr = target_node
	
	while curr != start_node:
		var info = visited[curr] # [parent, index]
		var parent = info[0]
		var exit_idx = info[1]
		
		path_segments.push_front("relocator %d --> %s" % [exit_idx + 1, curr])
		curr = parent
		
	return start_node + " --> " + " --> ".join(path_segments)


# final physical check of what is reachable with BFS
func _get_true_reachable_rooms(layout: Dictionary, start_node: String) -> Array[String]:
	var visited = {start_node: true}
	var queue = [start_node]
	var reachable: Array[String] = [start_node]
	
	while queue.size() > 0:
		var current = queue.pop_front()
		if not layout.has(current): continue
		
		for neighbor in layout[current]:
			if neighbor != "" and not visited.has(neighbor):
				visited[neighbor] = true
				reachable.append(neighbor)
				queue.append(neighbor)
				
	return reachable


@rpc("authority", "call_local", "reliable")
func sync_mansion_layout(layout_data: Dictionary):
	mansion_layout = layout_data
	
	# find and remove/queue_free orphans locally
	var world = get_parent()
	var client_orphans: Array[String] = []
	var current_rooms = get_parent().rooms_array
	for room in current_rooms:
		if room.name != "staircase" and not layout_data.has(room.name):
			client_orphans.append(room.name)
	if not client_orphans.is_empty():
		get_parent().delete_orphaned_rooms(client_orphans)
		
	# sync mansion
	for room_name in layout_data:
		var room_node = get_node_or_null(NodePath(room_name))
		if room_node and "relocators" in room_node:
			var targets = layout_data[room_name]
			for i in range(targets.size()):
				if i < room_node.relocators.size():
					var reloc = room_node.relocators[i]
					if not reloc.get("is_fixed_navigation"):
						reloc.room_name_to_switch_to = targets[i]
