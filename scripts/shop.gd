extends Node2D

enum ShopItemType { WEAPON, SUSPECT, LOCATION, \
	REFRESH_CARDS, PAUSE_TIMER, PLACE_CLUE, \
	MAP_CRYSTAL_BALL, MAP_CARDS, MAP_COINS }

@export var shop_item_scene: PackedScene = preload("uid://d3wsa6r1v7i3d")
@onready var error_audio_stream_player: AudioStreamPlayer = $ErrorAudioStreamPlayer
@onready var purchase_audio_stream_player: AudioStreamPlayer = $PurchaseAudioStreamPlayer

var slot_positions = [
	Vector2(-240, 0),
	Vector2(0, 40), 
	Vector2(240, 0)
]

var spawned_items: Array[Node] = []
var synced_item_types: Array = []
var bought_states: Array[bool] = [false, false, false]

func _ready():
	visibility_changed.connect(_on_visibility_changed)


func _on_visibility_changed():
	if visible:
		_spawn_synced_items()
	else:
		_clear_items()


@rpc("authority", "call_local", "reliable")
func sync_shop_inventory(new_items: Array):
	synced_item_types = new_items
	bought_states = [false, false, false]
	
	# if shop is open refresh immediately
	if visible:
		_clear_items()
		_spawn_synced_items()


func _spawn_synced_items():
	_clear_items()
	
	for i in range(synced_item_types.size()):
		var type = synced_item_types[i]
		
		if type == -1: continue 
		
		var new_item = shop_item_scene.instantiate()
		new_item.item_type = type
		new_item.slot_index = i
		new_item.position = slot_positions[i]
		
		if bought_states[i] == true:
			new_item.confirm_purchase()
		
		new_item.purchase_requested.connect(_on_purchase_requested)
		
		add_child(new_item)
		spawned_items.append(new_item)
		
		if i < 2:
			await get_tree().create_timer(0.2).timeout


func _clear_items():
	for item in spawned_items:
		if is_instance_valid(item):
			item.queue_free()
	spawned_items.clear()


func _on_purchase_requested(item: Node2D):
	request_purchase_server.rpc_id(1, item.slot_index, item.cost)


@rpc("any_peer", "call_local", "reliable")
func request_purchase_server(slot_idx: int, cost: int):
	if not multiplayer.is_server(): return
	
	if slot_idx < 0 or slot_idx >= synced_item_types.size(): return
	if bought_states[slot_idx] == true: return 

	if GameManager.coins >= cost:
		GameManager.coins -= cost
		GameManager.sync_turn_state.rpc(GameManager.current_time_remaining, GameManager.coins)
		
		_do_upgrade_ability(synced_item_types[slot_idx])
		
		sync_purchase_success.rpc(slot_idx)
		
	else:
		var sender_id = multiplayer.get_remote_sender_id()
		reject_purchase_client.rpc_id(sender_id, slot_idx)


@rpc("authority", "call_local", "reliable")
func sync_purchase_success(slot_idx: int):
	bought_states[slot_idx] = true
	purchase_audio_stream_player.play()
	
	for item in spawned_items:
		if item.slot_index == slot_idx:
			item.confirm_purchase()
			break


@rpc("authority", "call_local", "reliable")
func reject_purchase_client(slot_idx: int):
	error_audio_stream_player.play()
	for item in spawned_items:
		if item.slot_index == slot_idx:
			item.reject_purchase()
			break


func _do_upgrade_ability(item_type: int):
	match item_type:
		ShopItemType.WEAPON:
			GameManager.eliminate_incorrect_clue.rpc_id(1, 1)
		ShopItemType.SUSPECT:
			GameManager.eliminate_incorrect_clue.rpc_id(1, 2)
		ShopItemType.LOCATION:
			GameManager.eliminate_incorrect_clue.rpc_id(1, 3)
		ShopItemType.REFRESH_CARDS:
			GameManager.grant_ghost_powerup.rpc_id(1, "refresh_cards")
		ShopItemType.PAUSE_TIMER:
			GameManager.apply_timer_pause.rpc(60.0)
		ShopItemType.PLACE_CLUE:
			GameManager.grant_ghost_powerup.rpc_id(1, "place_clue")
		ShopItemType.MAP_CRYSTAL_BALL:
			GameManager.activate_map_reveal.rpc("crystal_ball")
		ShopItemType.MAP_CARDS:
			GameManager.activate_map_reveal.rpc("cards")
		ShopItemType.MAP_COINS:
			GameManager.activate_map_reveal.rpc("coins")
