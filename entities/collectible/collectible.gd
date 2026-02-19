class_name Collectible
extends Node2D

@onready var sprite_2d: Sprite2D = $Sprite2D
@onready var clickable_area: Node = $ClickableArea
@onready var audio_stream_player: AudioStreamPlayer = $AudioStreamPlayer

enum Type { BRONZE_COIN, SILVER_COIN, HOURGLASS }
@export var item_type: Type

var start_y: float
var float_tween: Tween

func _ready():
	start_y = position.y
	
	clickable_area.mouse_clicked.connect(_on_collectible_clicked)
	
	match item_type:
		Type.BRONZE_COIN:
			sprite_2d.texture = preload("uid://b23ljafgxhq8l")
			audio_stream_player.stream = preload("uid://b425sigrewc6f")
		Type.SILVER_COIN:
			sprite_2d.texture = preload("uid://dxx1idcw8d5y4")
			audio_stream_player.stream = preload("uid://b425sigrewc6f")
		Type.HOURGLASS:
			sprite_2d.texture = preload("uid://dife8bu1u8joa")
			audio_stream_player.stream = preload("uid://c2u327mud2mps")
	
	_start_floating_animation()


func _start_floating_animation():
	# infinitely looping hover animation
	float_tween = create_tween().set_loops()
	float_tween.tween_property(self, "position:y", start_y - 10.0, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	float_tween.tween_property(self, "position:y", start_y, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _on_collectible_clicked():
	if is_instance_valid(clickable_area):
		clickable_area.queue_free()
		Cursor.is_hovering = false
		
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
	if float_tween and float_tween.is_running():
		float_tween.kill()
		
	# pop and fade out
	var anim_duration = 0.4
	var tween = create_tween().set_parallel(true)
	tween.tween_property(self, "scale", Vector2(1.5, 1.5), anim_duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 0.0, anim_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "position:y", position.y - 40.0, anim_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	
	await tween.finished
	
	if audio_stream_player.playing:
		await audio_stream_player.finished
		
	queue_free()
