extends CanvasLayer

@onready var sprite_2d: Sprite2D = $Sprite2D

var is_hovering = false
var pointer = preload("res://assets/ui/pointer.png")
var cursor = preload("res://assets/ui/cursor.png")

var pointer_offset = Vector2(14, 40)
var cursor_offset = Vector2(34, 60)

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	sprite_2d.texture = cursor
	sprite_2d.offset = cursor_offset


func _process(_delta: float) -> void:
	sprite_2d.global_position = sprite_2d.get_global_mouse_position()

	#if Input.is_action_just_pressed("click"):
	#is_hovering = !is_hovering
	if is_hovering:
		sprite_2d.offset = pointer_offset
		sprite_2d.texture = pointer
	else:
		sprite_2d.offset = cursor_offset
		sprite_2d.texture = cursor
