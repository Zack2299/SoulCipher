extends Node

# Variables to be synced in the MultiplayerSynchronizer
@export var player_id: int
@export var player_name: String = "Player"
@export var current_room: String = "staircase"
@export var is_ghost: bool = false

func _ready():
	set_multiplayer_authority(player_id)
	add_to_group("players")

@rpc("any_peer", "call_local")
func change_room(room_name: String):
	if is_multiplayer_authority():
		current_room = SceneTransition.current_room
