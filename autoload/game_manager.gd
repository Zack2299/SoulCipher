extends Node

var state_machine: CallableStateMachine 
var current_world_node: Node = null

# game state
var current_track: int = 1
var current_subround: int = 1
var ghost_id: int = -1

var random_ghost = true


func _ready():
	state_machine = CallableStateMachine.new() 
	_setup_states()


func _setup_states():
	state_machine.add_states(_state_waiting, _on_waiting_enter, Callable())
	state_machine.add_states(_ghost_turn, _ghost_turn_enter, Callable())
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
	state_machine.set_initial_state(_ghost_turn) 


@rpc("authority", "call_local", "reliable")
func change_game_phase(phase_name: String):
	if phase_name == "player":
		state_machine.change_state(_player_turn)


# STATE FUNCTIONS
func _on_waiting_enter():
	print("GAME MANAGER [%d]: Waiting for server to initiate match..." % multiplayer.get_unique_id())


func _state_waiting():
	pass


func _ghost_turn_enter():
	print("GAME MANAGER [%d]: Starting ghost turn!" % multiplayer.get_unique_id())


func _ghost_turn():
	pass


func _player_turn():
	pass
