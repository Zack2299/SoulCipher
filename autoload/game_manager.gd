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

# config
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
	
	# check each category
	var categories = ["weapon", "suspect", "location"]
	for index in range(categories.size()):
		var category_name = categories[index]
		var type_index = index + 1 # 1: Weapon, 2: Suspect, 3: Location
		
		if player_submissions.has(type_index):
			if player_submissions[type_index] == targets[category_name]:
				if not solved_categories_in_current_track.has(category_name):
					correct_this_round.append(category_name)

	rpc("sync_round_results", correct_this_round)


@rpc("authority", "call_local", "reliable")
func sync_round_results(new_solved_categories: Array):
	# add newly found categories to persistent list
	for category in new_solved_categories:
		if not solved_categories_in_current_track.has(category):
			solved_categories_in_current_track.append(category)
	
	# check if track is complete
	if solved_categories_in_current_track.size() == 3:
		current_track += 1
		solved_categories_in_current_track.clear()
		# init next track's targets
		current_targets[current_track] = { "weapon": "", "suspect": "", "location": "" }
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


func _setup_states():
	state_machine.add_states(_state_waiting, _on_waiting_enter, _on_waiting_leave)
	state_machine.add_states(_ghost_turn, _ghost_turn_enter, _ghost_turn_leave)
	state_machine.add_states(_player_turn, _player_turn_enter, _player_turn_leave)
	state_machine.add_states(_end_round, _end_round_enter, Callable())
	state_machine.add_states(_end_game, _end_game_enter, Callable())
	
	state_machine.set_initial_state(_state_waiting)


func _process(_delta):
	state_machine.update() 


func start_match(assigned_ghost_id: int):
	if not multiplayer.is_server():
		return
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
	world_node.ghost_ui.visible = show


func _set_player_ui(show: bool, wait: float = 1.0):
	var local_id = multiplayer.get_unique_id()
	await get_tree().create_timer(wait).timeout
	if local_id != ghost_id:
		world_node.player_ui.visible = show


# --- GHOST TURN STATE ---
func _ghost_turn_enter():
	var local_id = multiplayer.get_unique_id()
	var to_reveal = []
	var to_hide = []

	if local_id == ghost_id:
		to_reveal.append(world_node.card_select)
	else:
		to_reveal.append(world_node.shop)
		to_hide.append(world_node.player_ui)
		
	# to_hide.append(end_round_info)

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
	
	# clear all clues in rooms (new round)
	world_node.clear_world_clues()

func _ghost_turn():
	pass


func _ghost_turn_leave():
	var local_id = multiplayer.get_unique_id()
	var to_hide = []
	var to_reveal = []

	if local_id == ghost_id:
		to_hide.append(world_node.card_select)
		to_reveal.append(world_node.ghost_ui)
	else:
		to_hide.append(world_node.shop)
		to_reveal.append(world_node.player_ui)

	SceneTransition.reveal_hide_transition(to_reveal, to_hide, 1.0)


# --- PLAYER TURN STATE ---
func _player_turn_enter():
	var local_id = multiplayer.get_unique_id()
	print("GAME MANAGER: ID [%d] entered PLAYER TURN." % local_id)


func _player_turn():
	pass


func _player_turn_leave():
	var local_id = multiplayer.get_unique_id()
	var to_hide = []
	var to_reveal = []

	if local_id == ghost_id:
		to_reveal.append(world_node.card_select)
	else:
		to_reveal.append(world_node.shop)
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
	
	# if correctly guessed weapon/person/place
	# current_track += 1


func _end_round():
	if current_round > total_rounds:
		state_machine.change_state(_end_game)
	else:
		state_machine.change_state(_ghost_turn)


# --- ENG GAME STATE
func _end_game_enter():
	var local_id = multiplayer.get_unique_id()
	print("GAME MANAGER: ID [%d] entered END GAME." % local_id)
	
	NetworkManager.start_game_for_all()


func _end_game():
	pass
