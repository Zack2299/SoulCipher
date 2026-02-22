extends Node2D

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
	_clear_items()
	
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
		
		match item.item_type:
			pass # implement functionality
	else:
		print("Not enough coins! Need ", item.cost, " but only have ", GameManager.coins)
		item.reject_purchase()
		error_audio_stream_player.play()
