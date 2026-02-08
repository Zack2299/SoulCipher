extends Node2D

@onready var clickable_area: Node = $CrystalBall/ClickableArea
@onready var crystal_ball_above: Sprite2D = $CrystalBallAbove
@onready var inside_crystal_ball: Sprite2D = $InsideCrystalBall


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	clickable_area.mouse_clicked.connect(_on_crystal_ball_clicked)


func _on_crystal_ball_clicked():
	var tween = create_tween()

	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)

	# Move .from() immediately after the tween_property call
	tween.tween_property(crystal_ball_above, "modulate:a", 1.0, 1).from(0.0)
	tween.tween_property(crystal_ball_above, "position:y", 40, 0.8).from(0.0)
	tween.tween_property(crystal_ball_above, "scale", Vector2(1.5, 1.5), 3).from(Vector2(0.9, 0.9))

	var delay = 0.7
	# Place .from() BEFORE .set_delay()
	tween.tween_property(inside_crystal_ball, "modulate:a", 1.0, 2).from(0.0).set_delay(delay)
	tween.tween_property(inside_crystal_ball, "scale", Vector2(1.0, 1.0), 0.8).from(Vector2(0.9, 0.9)).set_delay(delay)
