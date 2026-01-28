extends CanvasLayer

@onready var sprite_2d: Sprite2D = $Sprite2D

var is_hovering = false
#var pointer = preload("res://assets/ui/pointer.png")
var pointer = preload("res://assets/ui/pointer_animation.png")
var cursor = preload("res://assets/ui/cursor.png")

var pointer_offset = Vector2(14, 40)
var cursor_offset = Vector2(34, 60)

var pointer_animation_length = 3
var animation_speed: float = 8.0 # Frames per second
var time_passed: float = 0.0

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	sprite_2d.texture = cursor
	sprite_2d.offset = cursor_offset


func _process(delta: float) -> void:
	sprite_2d.global_position = sprite_2d.get_global_mouse_position()

	#if Input.is_action_just_pressed("click"):
	#is_hovering = !is_hovering
	if is_hovering:
		sprite_2d.offset = pointer_offset
		sprite_2d.texture = pointer
		
		# cycle through 3 frames of pointer animation
		sprite_2d.hframes = pointer_animation_length
		
		time_passed += delta
		var frame_index = int(time_passed * animation_speed) % pointer_animation_length
		sprite_2d.frame = frame_index
	else:
		sprite_2d.offset = cursor_offset
		sprite_2d.texture = cursor
		sprite_2d.frame = 0
		sprite_2d.hframes = 1
