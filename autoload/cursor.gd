extends CanvasLayer

@onready var sprite_2d: Sprite2D = $Sprite2D

var hovering = false


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN


func _process(_delta: float) -> void:
	sprite_2d.global_position = sprite_2d.get_global_mouse_position()
	
	if Input.is_action_just_pressed("click"):
		hovering = !hovering
		if hovering:
			sprite_2d.offset.x -= 20
			sprite_2d.offset.y -= 10
			sprite_2d.texture = preload("res://assets/ui/pointer.png")
		else:
			sprite_2d.offset.x += 20
			sprite_2d.offset.y += 10
			sprite_2d.texture = preload("res://assets/ui/cursor.png")
