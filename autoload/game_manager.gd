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

# config
var random_ghost = true
var total_rounds: int = 14

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


@rpc("authority", "call_local", "reliable")
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
	var category = _get_category_string(card_type)
	
	found_cards[phase_num][category][clue_path] = true
	
	print("SYNC: Card found and recorded globally: ", clue_path)
	
	world_node.spawn_clue_to_card_screen(clue_path, card_type)


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

## This is called to tell the server the player round is over
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
	
		# logic to differentiate UI
	if local_id == ghost_id:
		_set_ghost_ui(true)
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
	print("GAME MANAGER: ID [%d] entered GHOST TURN." % local_id)
	
	# logic to differentiate UI
	if game_just_started:
		if local_id == ghost_id:
			world_node.card_select.visible = true
		else:
			world_node.shop.visible = true
		game_just_started = false
	else:
		if local_id == ghost_id:
			_set_ghost_turn_ui(true)
		else:
			_set_investigator_waiting_ui(true)


func _ghost_turn():
	pass


func _ghost_turn_leave():
	#print("GAME MANAGER: ID [%d] left GHOST TURN." % multiplayer.get_unique_id())
	_set_ghost_turn_ui(false)
	_set_investigator_waiting_ui(false)
	_set_player_ui(true)


# --- GHOST HELPERS ---
func _set_ghost_turn_ui(show: bool):
	SceneTransition.set_visibility_transition(world_node.card_select, show, 1.0)


func _set_investigator_waiting_ui(show: bool):
	var local_id = multiplayer.get_unique_id()
	if local_id != ghost_id:
		SceneTransition.set_visibility_transition(world_node.player_ui, !show, 1.0)
	SceneTransition.set_visibility_transition(world_node.shop, show, 1.0)


# --- PLAYER TURN STATE ---
func _player_turn_enter():
	var local_id = multiplayer.get_unique_id()
	print("GAME MANAGER: ID [%d] entered PLAYER TURN." % local_id)


func _player_turn():
	pass


func _player_turn_leave():
	pass
	#print("GAME MANAGER: ID [%d] left PLAYER TURN." % multiplayer.get_unique_id())


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
