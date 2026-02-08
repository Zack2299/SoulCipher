extends Node2D

@onready var left_clickable_area: Node = $LeftArrow/ClickableArea
@onready var right_clickable_area: Node = $RightArrow/ClickableArea
@onready var tokens: Sprite2D = $Tokens
@onready var h_box_container: HBoxContainer = $HBoxContainer

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
	var tween = create_tween()

	tween.tween_property(tokens, "scale", Vector2(1.2, 1.2), 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	tween.tween_property(tokens, "scale", Vector2(1.0, 1.0), 0.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
