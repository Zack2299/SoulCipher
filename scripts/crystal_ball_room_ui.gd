extends Node2D

@onready var clickable_area: Node = $CrystalBall/ClickableArea
@onready var crystal_ball_above: Sprite2D = $CrystalBallAbove
@onready var inside_crystal_ball: Sprite2D = $InsideCrystalBall


@onready var left_clickable_area: Node = $InsideCrystalBall/LeftArrow/ClickableArea
@onready var right_clickable_area: Node = $InsideCrystalBall/RightArrow/ClickableArea
@onready var tokens: Sprite2D = $InsideCrystalBall/Tokens
@onready var token_audio_stream_player: AudioStreamPlayer = $TokenAudioStreamPlayer
@onready var area_2d: Area2D = $CrystalBall/Area2D

var crystal_ball_tween: Tween

const NUM_TOKENS = 3

func _ready() -> void:
	left_clickable_area.mouse_clicked.connect(_on_left_arrow_clicked)
	right_clickable_area.mouse_clicked.connect(_on_right_arrow_clicked)
	clickable_area.mouse_clicked.connect(_on_crystal_ball_clicked)


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


func _on_crystal_ball_clicked():
	if crystal_ball_tween and crystal_ball_tween.is_running():
		crystal_ball_tween.kill()
		
	crystal_ball_tween = create_tween()
	if get_parent().has_node("player_ui"):
		get_parent().player_ui.visible = false
	
	area_2d.visible = false

	crystal_ball_tween.set_parallel(true)
	crystal_ball_tween.set_trans(Tween.TRANS_CUBIC)
	crystal_ball_tween.set_ease(Tween.EASE_OUT)

	crystal_ball_tween.tween_property(crystal_ball_above, "modulate:a", 1.0, 1).from(0.0)
	crystal_ball_tween.tween_property(crystal_ball_above, "position:y", 40, 0.8).from(0.0)
	crystal_ball_tween.tween_property(crystal_ball_above, "scale", Vector2(1.5, 1.5), 3).from(Vector2(0.9, 0.9))

	var delay = 0.7
	crystal_ball_tween.tween_property(inside_crystal_ball, "modulate:a", 1.0, 2).from(0.0).set_delay(delay)
	crystal_ball_tween.tween_property(inside_crystal_ball, "scale", Vector2(1.0, 1.0), 0.8).from(Vector2(0.9, 0.9)).set_delay(delay)


func reset():
	if crystal_ball_tween and crystal_ball_tween.is_running():
		crystal_ball_tween.kill()
		
	crystal_ball_above.modulate.a = 0
	inside_crystal_ball.modulate.a = 0
	area_2d.visible = true
