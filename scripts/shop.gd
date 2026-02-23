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


func _ready():
	visibility_changed.connect(_on_visibility_changed)


func _on_visibility_changed():
	if visible:
		_deal_new_items()
	else:
		_clear_items()


func _deal_new_items():
	_clear_items() # just to be safe
	
	var all_types = [0, 1, 2, 3, 4, 5, 6, 7, 8]
	all_types.shuffle()
	
	for i in range(3):
		var new_item = shop_item_scene.instantiate()
		new_item.item_type = all_types[i]
		new_item.position = slot_positions[i]
		
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
	if GameManager.coins >= item.cost:
		GameManager.coins -= item.cost
		
		item.confirm_purchase()
		purchase_audio_stream_player.play()
		
		print("Purchased item: ", item.item_type, " for ", item.cost)
		
		_do_upgrade_ability(item.item_type)
	else:
		print("Not enough coins! Need ", item.cost, " but only have ", GameManager.coins)
		item.reject_purchase()
		error_audio_stream_player.play()


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
