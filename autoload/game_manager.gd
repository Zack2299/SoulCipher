extends Node

var state_machine: CallableStateMachine 
var world_node: World = null:
	set(value):
		world_node = value
		if world_node != null:
			_connect_world_signals()

# game state
var current_track: int = 1
#var current_subround: int = 1
var current_round: int = 1
var ghost_id: int = -1
var game_just_started = true
var solved_categories_in_current_track: Array[String] = []
var wrong_guesses_in_current_track: Array[String] = []
var solved_current_track = false
var max_turn_time: float = 240.0 # in seconds
var current_time_remaining: float = 0.0
var coins: int = 100:
	set(value):
		coins = value
		if world_node != null:
			world_node.coin_count_text.text = str(value)
		
		if multiplayer.is_server():
			sync_coins.rpc(value)
var current_delta: float = 0.0
var active_map_reveals: Array[String] = []
var pause_time_remaining: float = 0.0
var pause_time_length: float = 60.0
var match_is_active: bool = false
var current_shop_items: Array = []
var current_shop_bought: Array[bool] = [false, false, false]

var ghost_powerups: Dictionary = {
	"refresh_cards": 0,
	"place_clue": 0
}

# config
var debug = true
var random_ghost = true
var total_rounds: int = 14
var num_cards = 8

# phase_data[phase_index][category] = { target_path : [clue_paths] }
var phase_history: Dictionary = {
	1: { "weapon": {}, "suspect": {}, "location": {} },
	2: { "weapon": {}, "suspect": {}, "location": {} },
	3: { "weapon": {}, "suspect": {}, "location": {} }
}

var found_cards: Dictionary = {
	1: { "weapon": {}, "suspect": {}, "location": {} },
	2: { "weapon": {}, "suspect": {}, "location": {} },
	3: { "weapon": {}, "suspect": {}, "location": {} }
}

var current_targets: Dictionary = {
	1: { "weapon": "", "suspect": "", "location": "" },
	2: { "weapon": "", "suspect": "", "location": "" },
	3: { "weapon": "", "suspect": "", "location": "" }
}


@rpc("any_peer", "call_local", "reliable")
func grant_ghost_powerup(powerup_name: String):
	ghost_powerups[powerup_name] += 1
	
	update_ghost_ui_inventory.rpc_id(ghost_id, ghost_powerups)


@rpc("authority", "call_local", "reliable")
func update_ghost_ui_inventory(new_inventory: Dictionary):
	if world_node == null: 
		return
	
	world_node.ghost_ui.update_powerup_buttons(new_inventory)


@rpc("any_peer", "call_local", "reliable")
func request_consume_powerup(powerup_name: String):
	if multiplayer.get_remote_sender_id() != ghost_id: return
	
	if ghost_powerups[powerup_name] > 0:
		ghost_powerups[powerup_name] -= 1
		
		update_ghost_ui_inventory.rpc_id(ghost_id, ghost_powerups)
		
		_execute_powerup_effect(powerup_name)


func _execute_powerup_effect(powerup_name: String):
	match powerup_name:
		"refresh_cards":
			world_node.card_select.refresh_cards.rpc_id(ghost_id)
		"place_clue":
			pass


@rpc("authority", "call_local", "reliable")
func sync_turn_state(time_left: float, current_coins: int):
	current_time_remaining = time_left
	coins = current_coins
	world_node.timer_progress_bar.value = current_time_remaining / max_turn_time
	world_node.crystal_timer_progress_bar.value = world_node.timer_progress_bar.value


@rpc("any_peer", "call_local", "reliable")
func record_selection(phase_num: int, card_type: int, target_path: String, clue_path: String):
	var category = _get_category_string(card_type)
	
	# update current answer for this phase/type
	current_targets[phase_num][category] = target_path
	
	# add clue to history
	var history_dict = phase_history[phase_num][category]
	if not history_dict.has(target_path):
		history_dict[target_path] = []
	
	history_dict[target_path].append(clue_path)
	
	print("LOGGED: Phase %d | %s | Target: %s | Clue: %s" % [phase_num, category, target_path, clue_path])


@rpc("any_peer", "call_local", "reliable")
func sync_card_found(phase_num: int, card_type: int, clue_path: String):
	if not multiplayer.is_server(): return 
	
	var category = _get_category_string(card_type)
	
	# has this clue already been recorded?
	if found_cards[phase_num][category].has(clue_path):
		print("SERVER: Clue already processed, ignoring duplicate find.")
		return
	
	# record
	found_cards[phase_num][category][clue_path] = true
	
	spawn_clue_for_all_card_screens.rpc(phase_num, card_type, clue_path)


@rpc("authority", "call_local", "reliable")
func spawn_clue_for_all_card_screens(phase_num: int, card_type: int, clue_path: String):
	var category = _get_category_string(card_type)
	found_cards[phase_num][category][clue_path] = true # keep local client dicts in sync
	
	world_node.spawn_clue_to_card_screen(clue_path, card_type)


@rpc("any_peer", "call_local", "reliable")
func evaluate_crystal_ball_submissions():
	if not multiplayer.is_server(): 
		return
	
	var crystal_ball = world_node.crystal_ball_room_ui
	var player_submissions = crystal_ball.submissions
	var targets = current_targets[current_track]
	
	var correct_this_round: Array[String] = []
	var wrong_this_round: Array[String] = []
	
	# check each category
	var categories = ["weapon", "suspect", "location"]
	for index in range(categories.size()):
		var category_name = categories[index]
		var type_index = index + 1 # 1: Weapon, 2: Suspect, 3: Location
		
		if player_submissions.has(type_index):
			if player_submissions[type_index] == targets[category_name]:
				if not solved_categories_in_current_track.has(category_name):
					correct_this_round.append(category_name)
			else:
				wrong_this_round.append(player_submissions[type_index])

	rpc("sync_round_results", correct_this_round, wrong_this_round)


@rpc("authority", "call_local", "reliable")
func sync_round_results(new_solved_categories: Array, new_wrong_guesses: Array = []):
	# add newly found categories to persistent list
	for category in new_solved_categories:
		if not solved_categories_in_current_track.has(category):
			solved_categories_in_current_track.append(category)
			world_node.player_card_screen.clear_category(category)
	
	# add new wrong guesses to persistent list
	for wrong_guess in new_wrong_guesses:
		if not wrong_guesses_in_current_track.has(wrong_guess):
			wrong_guesses_in_current_track.append(wrong_guess)
	
	# check if track is complete
	if solved_categories_in_current_track.size() == 3:
		current_track += 1
		solved_current_track = true
		
		world_node.player_card_screen.clear_clues()
		
		# init next track's targets
		current_targets[current_track] = { "weapon": "", "suspect": "", "location": "" }
		
		wrong_guesses_in_current_track.clear()
		
		# add in correct answers from previous rounds as being disabled
		for i in range(1, current_track):
			var old_targets = current_targets[i]
			if old_targets["weapon"] != "": wrong_guesses_in_current_track.append(old_targets["weapon"])
			if old_targets["suspect"] != "": wrong_guesses_in_current_track.append(old_targets["suspect"])
			if old_targets["location"] != "": wrong_guesses_in_current_track.append(old_targets["location"])
	
		print("SYSTEM: Track complete! Moving to Track: ", current_track)
	else:
		print("SYSTEM: Track incomplete. Solved so far: ", solved_categories_in_current_track)


func _get_category_string(type: int) -> String:
	match type:
		1: return "weapon"
		2: return "suspect"
		3: return "location"
	return "unknown"


func _connect_world_signals():
	world_node.ghost_turn_over.connect(_on_ghost_turn_over)
	world_node.player_turn_over.connect(_on_player_turn_over)


func _ready():
	state_machine = CallableStateMachine.new() 
	_setup_states()
	
	multiplayer.peer_connected.connect(_on_peer_connected_game_logic)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected_game_logic)


func _on_peer_connected_game_logic(id: int):
	if not multiplayer.is_server(): return
	
	# late joiner
	if match_is_active:
		print("SERVER: Late joiner detected: ", id)
		
		NetworkManager.rpc_load_game_scene.rpc_id(id)
		
		# check if we need a ghost
		if ghost_id == -1:
			print("SERVER: Assigning late joiner as NEW GHOST")
			ghost_id = id
			# notify everyone (including existing players) that we have a new ghost
			sync_ghost_update.rpc(ghost_id)


@rpc("any_peer", "call_remote", "reliable")
func request_gamestate_sync():
	var sender_id = multiplayer.get_remote_sender_id()
	if multiplayer.is_server() and match_is_active:
		print("SERVER: Player ", sender_id, " is ready. Sending Game State Snapshot.")
		_send_full_state_snapshot(sender_id)


func _on_peer_disconnected_game_logic(id: int):
	if not multiplayer.is_server() or not match_is_active: return
	
	if id == ghost_id:
		print("SERVER: FATAL - The Ghost has disconnected!")
		ghost_id = -1
		sync_ghost_update.rpc(-1)
		# DONT end game - essentially we are on pause until a new player joins


func _send_full_state_snapshot(target_id: int):
	# package everything a new player needs to know to render the UI correctly
	var snapshot = {
		"current_track": current_track,
		"current_round": current_round,
		"ghost_id": ghost_id,
		"solved_categories": solved_categories_in_current_track,
		"wrong_guesses": wrong_guesses_in_current_track,
		"coins": coins,
		"time_remaining": current_time_remaining,
		"current_targets": current_targets,
		"phase_history": phase_history,
		"found_cards": found_cards,
		"state_name": _get_current_state_name(),
		"shop_inventory": world_node.shop.synced_item_types if world_node else [],
		"player_info": NetworkManager.player_info,
		"connected_ids": NetworkManager.connected_ids,
		"cb_weapons": world_node.crystal_ball_room_ui.weapon_paths,
		"cb_suspects": world_node.crystal_ball_room_ui.suspect_paths,
		"cb_locations": world_node.crystal_ball_room_ui.location_paths,
		"shop_items": current_shop_items,
		"shop_bought": current_shop_bought
	}
	
	receive_full_state_snapshot.rpc_id(target_id, snapshot)

func _get_current_state_name() -> String:    
	var s = state_machine.current_state
	
	if s == "_ghost_turn": return "ghost_turn"
	if s == "_player_turn": return "player_turn"
	if s == "_end_round": return "end_round"
	
	return "waiting"


@rpc("authority", "call_local", "reliable")
func receive_full_state_snapshot(data: Dictionary):
	# wait for the scene to actually exist
	while world_node == null:
		await get_tree().process_frame
	
	print("CLIENT: Applying Snapshot for state: ", data["state_name"])
	
	var cb = world_node.crystal_ball_room_ui
	cb.setup_crystal_ball(data["cb_suspects"], data["cb_weapons"], data["cb_locations"])
	
	if data.has("player_info"):
		NetworkManager.player_info = data["player_info"]
	if data.has("connected_ids"):
		NetworkManager.connected_ids = Array(data["connected_ids"], TYPE_INT, &"", null)


	# retype array
	if data.has("shop_bought"):
		current_shop_bought = Array(data["shop_bought"], TYPE_BOOL, &"", null)
	if world_node and world_node.shop:
		world_node.shop.bought_states = Array(data["shop_bought"], TYPE_BOOL, &"", null)

	# spawn everyone who is currently in the game
	for id in NetworkManager.connected_ids:
		world_node.spawn_player(id)

	# sync all data
	current_track = data["current_track"]
	current_round = data["current_round"]
	ghost_id = data["ghost_id"]
	solved_categories_in_current_track = data["solved_categories"]
	wrong_guesses_in_current_track = data["wrong_guesses"]
	coins = data["coins"]
	current_time_remaining = data["time_remaining"]
	current_targets = data["current_targets"]
	phase_history = data["phase_history"]
	found_cards = data["found_cards"]
	
	world_node.rebuild_player_ui()
	
	if data.has("shop_inventory"):
		world_node.shop.synced_item_types = data["shop_inventory"]
	
	# update the permanent UI elements
	world_node.coin_count_text.text = str(coins)
	
	# populate the card screen with clues already found
	world_node.refresh_found_clues_visuals()
	
	world_node.coin_count_text.text = str(coins)
	world_node.refresh_found_clues_visuals()

	var local_id = multiplayer.get_unique_id()

	# trigger state machine visuals
	match data["state_name"]:
		"ghost_turn":
			state_machine.change_state(_ghost_turn)
			if multiplayer.get_unique_id() != ghost_id:
				world_node.shop._spawn_synced_items()
		"player_turn":
			state_machine.change_state(_player_turn)
			if local_id != ghost_id:
				world_node.player_ui.visible = true
		"end_round":
			state_machine.change_state(_end_round)
		"waiting":
			state_machine.change_state(_state_waiting)


@rpc("authority", "call_local", "reliable")
func sync_ghost_update(new_id: int):
	if world_node == null:
		ghost_id = new_id
		return
		
	ghost_id = new_id
	var local_id = multiplayer.get_unique_id()
	
	if new_id == -1:
		print("SYSTEM: The Ghost is gone. Waiting for a replacement...")
		return

	# if I just became the ghost (due to late join or reassignment)
	if local_id == ghost_id:
		print("SYSTEM: You have become the Ghost!")
		_set_ghost_ui(true)
		_set_player_ui(false, 0.0)
		
		if state_machine.current_state == "_ghost_turn":
			world_node.card_select.visible = true
			world_node.card_select.start() 
			
	else:
		# I am not the ghost (anymore, or never was)
		_set_ghost_ui(false)
		world_node.card_select.visible = false
		
		if state_machine.current_state != "_end_round":
			world_node.player_ui.visible = true


func _setup_states():
	state_machine.add_states(_state_waiting, _on_waiting_enter, _on_waiting_leave)
	state_machine.add_states(_ghost_turn, _ghost_turn_enter, _ghost_turn_leave)
	state_machine.add_states(_player_turn, _player_turn_enter, _player_turn_leave)
	state_machine.add_states(_end_round, _end_round_enter, Callable())
	state_machine.add_states(_end_game, _end_game_enter, Callable())
	
	state_machine.set_initial_state(_state_waiting)


func _process(delta):
	current_delta = delta
	state_machine.update() 


func start_match(assigned_ghost_id: int):
	if not multiplayer.is_server():
		return
	match_is_active = true
	rpc("sync_match_start", assigned_ghost_id)


func _on_ghost_turn_over():
	rpc("change_game_phase", "player")


func _on_player_turn_over():
	rpc("change_game_phase", "end_round")


@rpc("any_peer", "call_local", "reliable")
func request_end_ghost_turn():
	if multiplayer.is_server():
		change_game_phase.rpc("player")


@rpc("any_peer", "call_local", "reliable")
func request_end_player_turn():
	if multiplayer.is_server():
		change_game_phase.rpc("end_round")


@rpc("authority", "call_local", "reliable")
func sync_match_start(id: int):
	ghost_id = id
	state_machine.change_state(_ghost_turn)


@rpc("authority", "call_local", "reliable")
func change_game_phase(phase_name: String):
	if phase_name == "player":
		state_machine.change_state(_player_turn)
	elif phase_name == "ghost":
		state_machine.change_state(_ghost_turn)
	elif phase_name == "end_round":
		state_machine.change_state(_end_round)


# --- WAITING STATE ---
func _on_waiting_enter():
	print("GAME MANAGER: [%d] entered WAITING state." % multiplayer.get_unique_id())


func _state_waiting():
	pass


func _on_waiting_leave():
	var local_id = multiplayer.get_unique_id()
	print("GAME MANAGER: ID [%d] left WAITING state." % local_id)
	
	if local_id == ghost_id:
		_set_ghost_ui(true)
		world_node.card_select.start()
	else:
		_set_player_ui(false)


# --- GHOST HELPERS ---
func _set_ghost_ui(show: bool):
	if world_node == null: 
		return
	world_node.ghost_ui.visible = show


func _set_player_ui(show: bool, wait: float = 1.0):
	var local_id = multiplayer.get_unique_id()
	await get_tree().create_timer(wait).timeout
	
	if world_node == null: 
		return
	
	if local_id != ghost_id:
		world_node.player_ui.visible = show


# --- GHOST TURN STATE ---
func _ghost_turn_enter():
	var local_id = multiplayer.get_unique_id()
	var to_reveal = []
	var to_hide = []

	if local_id == ghost_id:
		to_reveal.append(world_node.card_select)
		to_hide.append(world_node.player_ui)
	else:
		to_reveal.append(world_node.shop)
		to_hide.append(world_node.player_ui)
	
	to_hide.append(world_node.end_round_status_screen)
	# to_hide.append(end_round_info)
	
	if multiplayer.is_server():
		var all_types = [0, 1, 2, 3, 4, 6, 7, 8] # removed 5 (place a clue)
		all_types.shuffle()
		
		var shop_items = all_types.slice(0, 3)
		
		world_node.shop.sync_shop_inventory.rpc(shop_items)

	if game_just_started:
		for node in to_reveal: node.visible = true
		for node in to_hide: node.visible = false
		game_just_started = false
	else:
		SceneTransition.reveal_hide_transition(to_reveal, to_hide, 1.0)

	# refresh spawn rooms
	world_node.card_spawn_rooms = world_node.rooms_array.filter(func(room): 
		var is_special = room.name == "staircase" or room.name == "crystal_ball_room"
		
		return !is_special
	)


func _ghost_turn():
	pass


func _ghost_turn_leave():
	var local_id = multiplayer.get_unique_id()
	var to_hide = []
	var to_reveal = []

	if local_id == ghost_id:
		to_hide.append(world_node.card_select)
		to_reveal.append(world_node.ghost_ui)
		to_reveal.append(world_node.player_ui)
	else:
		to_hide.append(world_node.shop)
		to_reveal.append(world_node.player_ui)

	SceneTransition.reveal_hide_transition(to_reveal, to_hide, 1.0)


# --- PLAYER TURN STATE ---
func _player_turn_enter():
	var local_id = multiplayer.get_unique_id()
	print("GAME MANAGER: ID [%d] entered PLAYER TURN." % local_id)
	
	if multiplayer.is_server():
		current_time_remaining = max_turn_time
		sync_turn_state.rpc(current_time_remaining, coins)
		world_node.spawn_round_collectibles()


func _player_turn():
	world_node.frozen_progress_bar.modulate.a = pause_time_remaining / pause_time_length
	world_node.crystal_ball_frozen_progress_bar.modulate.a = pause_time_remaining / pause_time_length
	if pause_time_remaining > 0:
		pause_time_remaining -= current_delta
		return # skip draining actual timer while powerup active
	
	if current_time_remaining > 0:
		current_time_remaining -= current_delta
		world_node.timer_progress_bar.value = current_time_remaining / max_turn_time
		world_node.crystal_timer_progress_bar.value = world_node.timer_progress_bar.value
	elif multiplayer.is_server():
		evaluate_crystal_ball_submissions()
		change_game_phase.rpc("end_round")


func _player_turn_leave():
	var local_id = multiplayer.get_unique_id()
	var to_hide = []
	var to_reveal = []

	if local_id == ghost_id:
		#to_reveal.append(world_node.card_select)
		pass
	else:
		#to_reveal.append(world_node.shop)
		to_hide.append(world_node.player_ui)
		to_hide.append(world_node.crystal_ball_room_ui)
		to_hide.append(world_node.previous_room_relocator)

	SceneTransition.reveal_hide_transition(to_reveal, to_hide, 1.0)


# --- END ROUND STATE ---
func _end_round_enter():
	var local_id = multiplayer.get_unique_id()
	print("GAME MANAGER: ID [%d] entered END OF ROUND." % local_id)
	
	current_round += 1
	print("")
	print("----- Round ", current_round, " -----")
	
	_reset_powerups()
	
	SceneTransition.reveal_hide_transition([world_node.end_round_status_screen], [], 1.0)
	
	await get_tree().create_timer(1.0).timeout
	
	# clear all clues and collectibles in rooms (new round)
	world_node.clear_world_clues()
	world_node.clear_collectibles()
	
	await world_node.end_round_status_screen.display_results(solved_categories_in_current_track)
	
	#await get_tree().create_timer(7).timeout
	
	if solved_current_track:
		world_node.crystal_ball_room_ui.reset_submissions_new_track()
		solved_categories_in_current_track.clear()
		solved_current_track = false
	else:
		world_node.crystal_ball_room_ui.reset_submissions_same_track(solved_categories_in_current_track)
	
	if current_round > total_rounds:
		state_machine.change_state(_end_game)
	else:
		state_machine.change_state(_ghost_turn)
	
	# reset which room the player is in to staircase
	await get_tree().create_timer(1).timeout
	_reset_player_to_staircase()


func _reset_powerups():
	active_map_reveals.clear()
	pause_time_remaining = 0.0


func _end_round():	
	pass


func _reset_player_to_staircase():
	if SceneTransition.current_room_node:
		SceneTransition.current_room_node.visible = false
	var staircase_index = world_node.rooms_array.find_custom(func(room): return room.name == "staircase")
	var staircase_node = world_node.rooms_array[staircase_index]
	staircase_node.visible = true
	SceneTransition.current_room_node = staircase_node
	SceneTransition.current_room = "staircase"


# --- ENG GAME STATE
func _end_game_enter():
	var local_id = multiplayer.get_unique_id()
	print("GAME MANAGER: ID [%d] entered END GAME." % local_id)
	
	NetworkManager.start_game_for_all()


func _end_game():
	pass



# --- SHOP POWERUP RPC FUNCTIONS ---
@rpc("any_peer", "call_local", "reliable")
func eliminate_incorrect_clue(type: int):
	if not multiplayer.is_server(): return
	
	var category = _get_category_string(type)
	var target_path = current_targets[current_track][category]
	
	var crystal_ball = world_node.crystal_ball_room_ui
	var available_paths: Array = []
	
	match type:
		1: available_paths = crystal_ball.weapon_paths
		2: available_paths = crystal_ball.suspect_paths
		3: available_paths = crystal_ball.location_paths
		
	# find random wrong path that hasnt been guessed or eliminated yet
	var valid_wrong_paths: Array[String] = []
	for path in available_paths:
		if path != target_path and path != "" and not wrong_guesses_in_current_track.has(path):
			valid_wrong_paths.append(path)
			
	if valid_wrong_paths.size() > 0:
		var wrong_path = valid_wrong_paths.pick_random()
		
		sync_round_results.rpc([], [wrong_path])


@rpc("any_peer", "call_local", "reliable")
func apply_timer_pause(duration: float):
	pause_time_length = duration
	pause_time_remaining = duration


@rpc("any_peer", "call_local", "reliable")
func activate_map_reveal(reveal_type: String):
	if not active_map_reveals.has(reveal_type):
		active_map_reveals.append(reveal_type)


@rpc("authority", "call_remote", "reliable")
func sync_coins(new_amount: int):
	coins = new_amount
