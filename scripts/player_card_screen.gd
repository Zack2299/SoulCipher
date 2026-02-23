extends Node2D

@onready var left_clickable_area: Node = $LeftArrow/ClickableArea
@onready var right_clickable_area: Node = $RightArrow/ClickableArea
@onready var tokens: Sprite2D = $Tokens
@onready var token_audio_stream_player: AudioStreamPlayer = $TokenAudioStreamPlayer

const NUM_TOKENS = 3

func _ready() -> void:
	left_clickable_area.mouse_clicked.connect(_on_left_arrow_clicked)
	right_clickable_area.mouse_clicked.connect(_on_right_arrow_clicked)


func _on_left_arrow_clicked():
	if tokens.frame == 0:
		tokens.frame = NUM_TOKENS - 1
	else:
		tokens.frame -= 1
	_bounce_token()


func _on_right_arrow_clicked():
	tokens.frame = (tokens.frame + 1) % NUM_TOKENS
	_bounce_token()


func _bounce_token():
	token_audio_stream_player.pitch_scale = randf_range(1.9, 2.0)
	token_audio_stream_player.play()
	
	var tween = create_tween()

	tween.tween_property(tokens, "scale", Vector2(1.2, 1.2), 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	tween.tween_property(tokens, "scale", Vector2(1.0, 1.0), 0.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func clear_clues() -> void:
	var clues = get_tree().get_nodes_in_group("card_screen_clues")
	for clue in clues:
		clue.queue_free()


func clear_category(category: String) -> void:
	var clues = get_tree().get_nodes_in_group(category)
	for clue in clues:
		clue.queue_free()
