extends Control

var layout: Dictionary
var room_positions: Dictionary = {}

# layout tracking
var tree_parents: Dictionary = {}
var children_map: Dictionary = {}
var subtree_width: Dictionary = {}

# map visual config
@export var node_radius: float = 4.0
@export var x_spacing: float = 30.0
@export var y_spacing: float = 26.0
@export var line_thickness: float = 4.0


func _ready():
	visible = false


func _process(_delta):
	# redraw every frame while open so player icon tracks movement instantly
	if visible:
		queue_redraw()


func open_map():
	layout = GameManager.world_node.room_manager.mansion_layout
	if layout.is_empty(): 
		print("Map data not available yet!")
		return
		
	_calculate_map_coordinates()
	visible = true


func close_map():
	visible = false


func _calculate_map_coordinates():
	room_positions.clear()
	tree_parents.clear()
	children_map.clear()
	subtree_width.clear()
	
	# figure out who is the parent/child of who, and sort by door side
	_build_spanning_tree()
	
	# calculate how wide each branch needs to be so they never overlap
	_calc_widths("staircase")
	
	# assign actual x and y coordinates based on those widths
	_assign_positions("staircase", 0.0, 0)


func _build_spanning_tree():
	var visited = {"staircase": true}
	var queue = ["staircase"]
	
	var rooms_array = GameManager.world_node.rooms_array
	var get_room_node = func(r_name: String) -> Node:
		for r in rooms_array:
			if r.name == r_name: return r
		return null
		
	while queue.size() > 0:
		var curr = queue.pop_front()
		children_map[curr] = []
		var node = get_room_node.call(curr)
		
		var sorted_targets = []
		for i in range(layout[curr].size()):
			var target = layout[curr][i]
			if target != "" and not visited.has(target):
				var side = 2 # neutral
				if node and i < node.relocators.size():
					side = node.relocators[i].relocator_side
				sorted_targets.append({"name": target, "side": side})
				
		# sort targets: left doors (0) go left, neutral (2) middle, right doors (1) go right
		var weight_map = {0: 0, 2: 1, 1: 2}
		sorted_targets.sort_custom(func(a, b): return weight_map[a.side] < weight_map[b.side])
		
		for t in sorted_targets:
			visited[t.name] = true
			children_map[curr].append(t.name)
			tree_parents[t.name] = curr
			queue.append(t.name)


func _calc_widths(node: String) -> float:
	if not children_map.has(node) or children_map[node].is_empty():
		subtree_width[node] = 1.0 # leaf nodes take 1 unit of horizontal space
		return 1.0
		
	var width = 0.0
	for child in children_map[node]:
		width += _calc_widths(child)
		
	# add padding between sibling branches so they stay far apart visually
	width += (children_map[node].size() - 1) * 0.5 
	subtree_width[node] = max(1.0, width)
	return subtree_width[node]


func _assign_positions(node: String, x_center: float, depth: int):
	# -y because we want the tree to grow up
	room_positions[node] = Vector2(x_center * x_spacing, -depth * y_spacing)
	
	if not children_map.has(node) or children_map[node].is_empty(): return
	
	var start_x = x_center - (subtree_width[node] / 2.0)
	var current_x = start_x
	
	# place children side by side
	for child in children_map[node]:
		var child_w = subtree_width[child]
		var child_center = current_x + (child_w / 2.0)
		
		_assign_positions(child, child_center, depth + 1)
		current_x += child_w + 0.5 # add padding before the next sibling


func _draw():
	if room_positions.is_empty(): return
	
	var screen_center = size / 2
	# staircase in bottom center of screen
	var map_origin = Vector2(screen_center.x, size.y - 50) 
	var rooms_array = GameManager.world_node.rooms_array
	
	# draw hallways
	for room in layout:
		if not room_positions.has(room): continue
		var p1 = map_origin + room_positions[room]
		
		for neighbor in layout[room]:
			if neighbor != "" and room_positions.has(neighbor):
				var p2 = map_origin + room_positions[neighbor]
				
				var is_primary = (tree_parents.has(neighbor) and tree_parents[neighbor] == room) or (tree_parents.has(room) and tree_parents[room] == neighbor)
					
				if is_primary:
					draw_line(p1, p2, Color.DARK_GRAY, line_thickness)
				else:
					_draw_curved_line(p1, p2, Color(0.4, 0.6, 0.9, 0.7), line_thickness - 0.5)
				
	# draw rooms
	for room in room_positions:
		var p = map_origin + room_positions[room]
		var is_current_room = (room == SceneTransition.current_room)
		var color = Color.WHITE
		
		var has_coins = false
		
		# check physical room node for cards
		var clue_type = -1
		for r_node in rooms_array:
			if r_node.name == room:
				# look for a spawned card in children
				for child in r_node.get_children():
					if child.is_in_group("world_clues"):
						clue_type = child.card_type
					
					if child.is_in_group("coins"):
						has_coins = true
				break
		
		# color coding
		if room == "crystal_ball_room":
			if GameManager.active_map_reveals.has("crystal_ball") or GameManager.debug:
				color = Color.TEAL
			else:
				color = Color.WHITE
		#elif room == "staircase":
			#color = Color.GOLD
			
		if GameManager.active_map_reveals.has("cards") or GameManager.debug:
			if clue_type == 1:
				color = Color.CRIMSON # weapon
			elif clue_type == 2:
				color = Color.DODGER_BLUE # suspect
			elif clue_type == 3:
				color = Color.MEDIUM_PURPLE # location
				
		if GameManager.active_map_reveals.has("coins") and has_coins:
			color = Color.YELLOW
			
		draw_circle(p, node_radius, color)
		
		if GameManager.active_map_reveals.has("coins") and has_coins:
			draw_circle(p, node_radius + 1.0, Color.YELLOW, false, 1.0)
		
		# highlighted ring around player's current room
		if is_current_room and (not GameManager.active_map_reveals.is_empty() or GameManager.debug):
			draw_circle(p, node_radius + 1.5, Color.GREEN, false, 1.0)


# bezier curve helper
func _draw_curved_line(p1: Vector2, p2: Vector2, color: Color, thickness: float):
	var mid = (p1 + p2) / 2.0
	var dir = (p2 - p1).normalized()
	var normal = Vector2(-dir.y, dir.x)
	
	# curve always bows outward from the center of the screen
	var map_center_x = size.x / 2.0
	var center_dir = sign(mid.x - map_center_x)
	if center_dir == 0: center_dir = 1
	
	if sign(normal.x) != center_dir and normal.x != 0:
		normal = -normal
		
	# push midpoint outward slightly so it doesn't cross the main trunk
	var control = mid + (normal * 26.6)
	
	var points = PackedVector2Array()
	var segments = 16
	for i in range(segments + 1):
		var t = i / float(segments)
		var q = (1.0 - t) * (1.0 - t) * p1 + 2.0 * (1.0 - t) * t * control + t * t * p2
		points.append(q)
		
	draw_polyline(points, color, thickness, false)
