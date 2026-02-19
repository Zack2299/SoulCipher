class_name Collectible
extends Node2D

@onready var sprite_2d: Sprite2D = $Sprite2D
@onready var clickable_area: Node = $ClickableArea

enum Type { BRONZE_COIN, SILVER_COIN, HOURGLASS }
@export var item_type: Type

var start_y: float

func _ready():
	start_y = position.y
	
	clickable_area.mouse_clicked.connect(_on_collectible_clicked)
	
	match item_type:
		Type.BRONZE_COIN:
			sprite_2d.texture = preload("uid://b23ljafgxhq8l")
		Type.SILVER_COIN:
			sprite_2d.texture = preload("uid://dxx1idcw8d5y4")
		Type.HOURGLASS:
			sprite_2d.texture = preload("uid://dife8bu1u8joa")
	_start_floating_animation()


func _start_floating_animation():
	# infinitely looping hover animation
	var tween = create_tween().set_loops()
	tween.tween_property(self, "position:y", start_y - 10.0, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "position:y", start_y, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _on_collectible_clicked():
	request_collection.rpc_id(1)


@rpc("any_peer", "call_local", "reliable")
func request_collection():
	if not multiplayer.is_server(): return
	
	match item_type:
		Type.BRONZE_COIN:
			GameManager.coins += 1
		Type.SILVER_COIN:
			GameManager.coins += 3
		Type.HOURGLASS:
			GameManager.current_time_remaining += 15.0
			
	GameManager.sync_turn_state.rpc(GameManager.current_time_remaining, GameManager.coins)
	
	destroy_item.rpc()


@rpc("authority", "call_local", "reliable")
func destroy_item():
	queue_free()
