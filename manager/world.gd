class_name World
extends Node2D

enum CollectibleType { BRONZE_COIN, SILVER_COIN, HOURGLASS }

@onready var room_manager: Node2D = $RoomManager
@onready var previous_room_relocator: Node2D = $PreviousRoomRelocator
@onready var players_data: Node2D = $PlayersData
@onready var player_ui_hbox: HBoxContainer = $PlayerUI/PlayerUIHbox

@onready var ghost_ui: CanvasLayer = $GhostUI
@onready var player_ui: CanvasLayer = $PlayerUI
@onready var shop: Node2D = $Shop
@onready var card_select: Node2D = $CardSelect
@onready var player_card_screen: Node2D = $PlayerCardScreen
@onready var crystal_ball_room_ui: Node2D = $CrystalBallRoomUI
@onready var end_round_status_screen: Node2D = $EndRoundStatusScreen
@onready var timer_progress_bar: TextureProgressBar = $PlayerUI/TimerProgressBar
@onready var crystal_timer_progress_bar: TextureProgressBar = $CrystalBallRoomUI/InsideCrystalBall/TimerProgressBar
#@onready var minimap_ui: Control = $PlayerUI/MinimapUI
@onready var minimap_ui: Control = $PlayerUI/MinimapUI/SubViewport/MinimapUI
@onready var frozen_progress_bar: Sprite2D = $PlayerUI/FrozenProgressBar
@onready var crystal_ball_frozen_progress_bar: Sprite2D = $CrystalBallRoomUI/InsideCrystalBall/FrozenProgressBar
@onready var coin_count_text: Label = $Shop/CoinCount/CoinCountText
@onready var end_game_sprite: Sprite2D = $EndGameScreen/EndGameSprite
@onready var end_game_screen: Node2D = $EndGameScreen
@onready var restart_game_button: Button = $EndGameScreen/RestartGameButton


@export_dir var rooms_file_path: String = "res://rooms/"

const WORLD_CLUE_SCENE = preload("res://entities/world_clue/world_clue.tscn")
const COLLECTIBLE_SCENE = preload("res://entities/collectible/collectible.tscn")

var collectible_counter: int = 0 # unique id across network

var loaded_scenes: Array[PackedScene] = []
var rooms_array: Array[Node] = []
var card_spawn_rooms: Array[Node] = []
var orphaned_room_names: Array[String] = []
var havent_explored_rooms = true
var player_card_screen_is_shown
var has_started_searching = false
var is_showing_crystal_ball_ui = false
var minimap_showing = false

signal ghost_turn_over
signal player_turn_over

var players_loaded: Array[int] = []

func _input(event: InputEvent) -> void:
	## --- DEBUG ---
	#if event.is_action_pressed("one"):
		#request_phase_change.rpc("ghost_turn_over")
	#elif event.is_action_pressed("two"):
		#request_phase_change.rpc("player_turn_over")
		#
	if event.is_action_pressed("open_player_card_screen"):
		if multiplayer.get_unique_id() != GameManager.ghost_id:
			player_card_screen_is_shown = !player_card_screen_is_shown
			if player_card_screen_is_shown:
				SceneTransition.reveal_hide_transition([player_card_screen], [player_ui, previous_room_relocator, room_manager, crystal_ball_room_ui])
			elif is_showing_crystal_ball_ui:
				SceneTransition.reveal_hide_transition([previous_room_relocator, room_manager, crystal_ball_room_ui], [player_ui, player_card_screen])
			else:
				if !has_started_searching:
					SceneTransition.reveal_hide_transition([player_ui, room_manager], [player_card_screen])
				else:
					SceneTransition.reveal_hide_transition([player_ui, previous_room_relocator, room_manager], [player_card_screen])
	elif event.is_action_pressed("open_minimap"):
		minimap_showing = not minimap_showing
		if minimap_showing:
			minimap_ui.open_map()
		else:
			minimap_ui.close_map()


@rpc("any_peer", "call_local", "reliable")
func request_phase_change(type: String):
	if not multiplayer.is_server():
		return
		
	if type == "ghost_turn_over":
		ghost_turn_over.emit()
	elif type == "player_turn_over":
		player_turn_over.emit()


func _ready() -> void:
	NetworkManager.world_node = self
	GameManager.world_node = self
	SceneTransition.world_node = self
	
	player_card_screen_is_shown = player_card_screen.visible
	
	load_scenes_from_folder()
	
	if not multiplayer.is_server():
		room_manager.request_mansion_sync.rpc_id(1)
		
	if not multiplayer.is_server():
		GameManager.request_gamestate_sync.rpc_id(1)
	
	spawn_rooms_to_world(loaded_scenes)
	
	# small delay ensures the sync_connected_ids RPC has landed on clients
	await get_tree().process_frame
	
	print("World ready. Spawning connected players: ", NetworkManager.connected_ids)
	for id in NetworkManager.connected_ids:
		spawn_player(id)
		
	#if multiplayer.is_server():
		#_server_initialize_match()
		
	card_select.visibility_changed.connect(_on_card_select_visibility_changed)
	shop.visibility_changed.connect(_on_shop_visibility_changed)
	
	var my_id = multiplayer.get_unique_id()
	notify_server_loaded.rpc_id(1, my_id)


@rpc("any_peer", "call_local", "reliable")
func notify_server_loaded(peer_id: int):
	if not multiplayer.is_server():
		return
		
	if not players_loaded.has(peer_id):
		players_loaded.append(peer_id)
		print("SERVER: Player %d has loaded the world scene." % peer_id)
		
	# check if the number of loaded players matches the connected players
	if players_loaded.size() == NetworkManager.connected_ids.size():
		print("SERVER: All players loaded. Starting match!")
		_server_initialize_match()


func delete_orphaned_rooms(orphaned_names: Array[String]) -> void:
	if orphaned_names.is_empty():
		return
		
	print("Cleanup: Removing %d orphaned rooms..." % orphaned_names.size())
	
	# find the node, remove it from the array, and queue_free
	for room_name in orphaned_names:
		var node_to_remove: Node = null
		
		# find node based on name
		for room in rooms_array:
			if room.name == room_name:
				node_to_remove = room
				break
		
		if node_to_remove:
			rooms_array.erase(node_to_remove)
			node_to_remove.queue_free()


func _on_card_select_visibility_changed():
	room_manager.visible = !card_select.visible


func _on_shop_visibility_changed():
	room_manager.visible = !shop.visible


func _server_initialize_match():
	# ensure we have players
	var player_ids = NetworkManager.connected_ids
	if player_ids.is_empty():
		return
	
	var ghost_id = 1 # server is ghost as default
	if GameManager.random_ghost:
		ghost_id = player_ids[randi() % player_ids.size()]
	
	print("SERVER: Match starting. Ghost: ", ghost_id)
	
	# start global game manager state machine
	GameManager.start_match(ghost_id)


func spawn_clue_in_specific_room(texture_path: String, type_index: int, room_idx: int):
	# add card to room
	var target_room = rooms_array[room_idx]
	var new_clue = WORLD_CLUE_SCENE.instantiate()
	target_room.add_child(new_clue)
	
	#new_clue.remove_from_group("ghost_cards")
	new_clue.add_to_group("world_clues")
	
	new_clue.card_found.connect(_on_world_clue_found)
	
	var front_tex = load(texture_path)
	new_clue.setup(new_clue.back_spritesheet, type_index, front_tex, Vector2.ZERO, Rect2())
	
	# random position
	new_clue.position = Vector2(randf_range(-100, 100), randf_range(-100, 100))
	
	print("CARD ADDED: Type %d ('%s') spawned in room: %s" % [type_index, texture_path.get_file(), target_room.name])


func spawn_clue_to_card_screen(texture_path: String, type_index: int):
	# add card to card screen
	var target = player_card_screen
	var new_clue = WORLD_CLUE_SCENE.instantiate()
	target.add_child(new_clue)
	
	#new_clue.remove_from_group("ghost_cards")
	new_clue.add_to_group("card_screen_clues")
	match type_index:
		1: new_clue.add_to_group("weapon")
		2: new_clue.add_to_group("suspect")
		3: new_clue.add_to_group("location")
	
	var front_tex = load(texture_path)
	
	# random position
	var random_pos = Vector2(randf_range(-20, 20), randf_range(-20, 20))
	
	new_clue.setup(new_clue.back_spritesheet, type_index, front_tex, random_pos, Rect2(), false)


func clear_world_clues():
	var clues = get_tree().get_nodes_in_group("world_clues")
	for clue in clues:
		clue.queue_free()


func clear_collectibles():
	var items = get_tree().get_nodes_in_group("collectibles")
	for item in items:
		item.queue_free()


func spawn_round_collectibles():
	if not multiplayer.is_server(): return
	
	var valid_rooms = rooms_array.filter(func(r): return r.name != "staircase" and r.name != "crystal_ball_room")
	if valid_rooms.is_empty(): return
	
	for i in range(randi_range(5,10)):
		_generate_collectible_data(CollectibleType.BRONZE_COIN, valid_rooms.pick_random())
		
	for i in range(randi_range(3,5)):
		_generate_collectible_data(CollectibleType.HOURGLASS, valid_rooms.pick_random())
		
	for i in range(randi_range(1,3)):
		_generate_collectible_data(CollectibleType.SILVER_COIN, valid_rooms.pick_random())


func _generate_collectible_data(item_type: int, target_room: Node):
	var room_idx = rooms_array.find(target_room)
	
	var random_pos = Vector2(randf_range(-300, 300), randf_range(-160, 160))
	
	collectible_counter += 1
	var unique_name = "Collectible_" + str(collectible_counter)
	
	# spawn item for clients and server
	sync_spawn_collectible.rpc(item_type, room_idx, random_pos, unique_name)


@rpc("authority", "call_local", "reliable")
func sync_spawn_collectible(item_type: int, room_idx: int, pos: Vector2, item_name: String):	
	var item = COLLECTIBLE_SCENE.instantiate()
	
	item.item_type = item_type # assign the enum type BEFORE it enters the tree
	item.name = item_name # make node paths match
	item.position = pos
	item.add_to_group("collectibles")
	if item_type == 0 or item_type == 1:
		item.add_to_group("coins")
	
	# ghost can't see/pickup coins or hourglasses
	if multiplayer.get_unique_id() == GameManager.ghost_id:
		item.visible = false
	
	rooms_array[room_idx].add_child(item)


func _on_world_clue_found(clue: WorldClue):
	# ghost cannot find clues
	if multiplayer.get_unique_id() == GameManager.ghost_id:
		return
	
	var texture_path = clue.front_texture.resource_path
	GameManager.sync_card_found.rpc(GameManager.current_track, clue.card_type, texture_path)


func refresh_all_ui_visibility():
	get_tree().call_group("player_uis", "update_visibility")


func load_scenes_from_folder() -> void:
	var dir = DirAccess.open(rooms_file_path)
	if dir:
		for file_name in dir.get_files():
			var clean_file_name = file_name.trim_suffix(".remap")
			
			if clean_file_name.ends_with(".tscn"):
				var full_path = rooms_file_path + "/" + clean_file_name
				var scene_resource = load(full_path)
				if scene_resource is PackedScene:
					loaded_scenes.append(scene_resource)
	else:
		print("Couldn't access path")


func spawn_rooms_to_world(scenes_array: Array[PackedScene]) -> void:
	for scene in scenes_array:
		if scene:
			var room_instance = scene.instantiate()
			room_instance.name = scene.resource_path.get_file().get_basename()
			room_manager.add_child(room_instance)
			rooms_array.push_back(room_instance)
			
			if room_instance.name == "staircase":
				room_instance.visible = true
			else:
				room_instance.visible = false

	if multiplayer.is_server():
		get_tree().create_timer(0.5).timeout.connect(func(): room_manager.generate_mansion(rooms_array))


func _process(_delta: float) -> void:
	if SceneTransition.previous_room != "":
		previous_room_relocator.room_name_to_switch_to = SceneTransition.previous_room
	
	if !has_started_searching and SceneTransition.current_room != "staircase":
		has_started_searching = true


#func spawn_player(id: int):
	#if players_data.has_node(str(id)): 
		#return
	#
	## spawn ui
	#var p_ui = preload("res://entities/player_container/player_container.tscn").instantiate()
	#p_ui.name = "UI_" + str(id) 
	#player_ui_hbox.add_child(p_ui)
	#
	## setup data node
	#var p_data = preload("res://manager/player_data.tscn").instantiate()
	#p_data.name = str(id) # name matches peer id
	#p_data.player_id = id
	#
	#if multiplayer.is_server():
		#var info = NetworkManager.player_info.get(id, {"name": "Guest", "avatar": 0})
		#p_data.player_name = info["name"]
		#p_data.avatar_id = info["avatar"]
	#
	#p_data.update_player_ui.connect(_on_update_player_ui)
	#
	#players_data.add_child(p_data)
	#
	## init ui
	#p_ui.setup(p_data)
func spawn_player(id: int):
	if players_data.has_node(str(id)): 
		return
	
	# setup data node first
	var p_data = preload("res://manager/player_data.tscn").instantiate()
	p_data.name = str(id) 
	p_data.player_id = id
	
	# ensure late-joiner knows who everyone is
	var info = NetworkManager.player_info.get(id, {"name": "Guest", "avatar": 0})
	p_data.player_name = info["name"]
	p_data.avatar_id = info["avatar"]
	
	p_data.update_player_ui.connect(_on_update_player_ui)
	players_data.add_child(p_data)

	# spawn ui node
	var p_ui = preload("res://entities/player_container/player_container.tscn").instantiate()
	p_ui.name = "UI_" + str(id) 
	player_ui_hbox.add_child(p_ui)
	
	# init ui with data
	p_ui.setup(p_data)
	
	# manual visual update 
	# (sometimes signals fire before the UI is ready; this is a safety catch)
	_on_update_player_ui(id, p_data.avatar_id)
	
	print("WORLD: Spawned player %d (%s)" % [id, p_data.player_name])


func _on_update_player_ui(id: int, avatar_index: int):
	var ui_node_name = "UI_" + str(id)
	var ui_node = player_ui_hbox.get_node_or_null(ui_node_name)
	
	if ui_node and ui_node.is_inside_tree():
		if ui_node.sprite_2d:
			ui_node.sprite_2d.frame = avatar_index


func despawn_player(id: int):
	var data_node = players_data.get_node_or_null(str(id))
	if data_node:
		data_node.queue_free()
		
	var ui_node = player_ui_hbox.get_node_or_null("UI_" + str(id))
	if ui_node:
		ui_node.queue_free()


func show_crystal_ball_room_ui():
	crystal_ball_room_ui.visible = true
	is_showing_crystal_ball_ui = true


func hide_crystal_ball_room_ui():
	crystal_ball_room_ui.visible = false
	is_showing_crystal_ball_ui = false
	player_ui.visible = true
	crystal_ball_room_ui.reset_visuals()
	
	
func refresh_found_clues_visuals():
	clear_world_clues()
	player_card_screen.clear_clues()
	
	# respawn clues on the player's card screen
	# loop through the found_cards dictionary in GameManager
	for phase_num in GameManager.found_cards:
		var phase_data = GameManager.found_cards[phase_num]
		for category in phase_data:
			var clues_in_cat = phase_data[category]
			for clue_path in clues_in_cat:
				var type_index = 0
				match category:
					"weapon": type_index = 1
					"suspect": type_index = 2
					"location": type_index = 3
				
				# only show clues for the current track or solved categories
				spawn_clue_to_card_screen(clue_path, type_index)
	
	print("WORLD: Visual clue state refreshed for new player.")


func rebuild_player_ui():
	# clear existing UI containers
	for child in player_ui_hbox.get_children():
		child.queue_free()
	
	# respawn UI for every PlayerData node currently in the tree
	for p_data in players_data.get_children():
		var p_ui = preload("res://entities/player_container/player_container.tscn").instantiate()
		p_ui.name = "UI_" + p_data.name 
		player_ui_hbox.add_child(p_ui)
		p_ui.setup(p_data)
		# Force the frame update immediately
		if p_ui.has_node("Sprite2D"):
			p_ui.get_node("Sprite2D").frame = p_data.avatar_id
