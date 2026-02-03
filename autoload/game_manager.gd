extends Node

var state_machine: CallableStateMachine 
var world_node: Node = null

# game state
var current_track: int = 1
var current_subround: int = 1
var current_round: int = 1
var ghost_id: int = -1

# config
var random_ghost = true
var total_rounds: int = 14


func _ready():
	state_machine = CallableStateMachine.new() 
	_setup_states()


func _setup_states():
	state_machine.add_states(_state_waiting, _on_waiting_enter, Callable())
	state_machine.add_states(_ghost_turn, _ghost_turn_enter, _ghost_turn_leave)
	state_machine.add_states(_player_turn, Callable(), Callable())
	
	state_machine.set_initial_state(_state_waiting)


func _process(_delta):
	state_machine.update() 


func start_match(assigned_ghost_id: int):
	if not multiplayer.is_server():
		return
	rpc("sync_match_start", assigned_ghost_id)


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


# --- WAITING STATE ---
func _on_waiting_enter():
	print("GAME MANAGER: [%d] entered WAITING state." % multiplayer.get_unique_id())


func _state_waiting():
	pass


func _on_waiting_leave():
	print("GAME MANAGER: ID [%d] left WAITING state." % multiplayer.get_unique_id())


# --- GHOST TURN STATE ---
func _ghost_turn_enter():
	var local_id = multiplayer.get_unique_id()
	print("GAME MANAGER: ID [%d] entered GHOST TURN." % local_id)
	
	# logic to differentiate UI
	if local_id == ghost_id:
		_set_ghost_ui(true)
	else:
		_set_investigator_waiting_ui(true)


func _ghost_turn():
	pass


func _ghost_turn_leave():
	print("GAME MANAGER: ID [%d] left GHOST TURN." % multiplayer.get_unique_id())
	_set_ghost_ui(false)
	_set_investigator_waiting_ui(false)



# --- GHOST HELPERS ---
func _set_ghost_ui(show: bool):
	#world_node
	pass


func _set_investigator_waiting_ui(show: bool):
	pass


# --- PLAYER TURN STATE ---
func _player_turn():
	pass
