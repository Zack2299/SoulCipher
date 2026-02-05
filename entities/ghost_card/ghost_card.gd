extends Sprite2D

signal card_selected

@onready var hitbox: ColorRect = $Hitbox
@onready var mask_layer: NinePatchRect = $MaskLayer
@onready var clue_art: Sprite2D = $MaskLayer/ClueArt
@onready var card_frame: NinePatchRect = $CardFrame
@onready var card_flip_audio_stream_player: AudioStreamPlayer = $CardFlipAudioStreamPlayer

# Config
var front_texture: Texture2D
var back_spritesheet: Texture2D = preload("uid://c0ewypdlrhiqr")
var back_frame: int
var is_revealed: bool = false
var anchor_point: Vector2
var bounds_rect: Rect2

# Dragging variables
var is_dragging: bool = false
var drag_offset: Vector2 = Vector2.ZERO

var noise = FastNoiseLite.new()
var noise_time: float = 0.0

@export_group("Floating")
@export var float_speed: float = 0.5
@export var float_range: float = 100.0 

@export_group("Physics")
@export var repulsion_radius: float = 200.0
@export var repulsion_strength: float = 5.0
# --- ADDED MISSING EXPORTS BELOW ---
@export var border_margin: float = 50.0
@export var border_push_strength: float = 3.0


func _ready():
	add_to_group("ghost_cards")
	noise.seed = randi()
	noise.frequency = 0.01
	centered = true
	
	mask_layer.visible = false
	card_frame.visible = false


func setup(back_tex: Texture2D, frame_idx: int, front_tex: Texture2D, start_pos: Vector2, spawn_rect: Rect2):
	texture = back_tex
	hframes = 4  
	frame = frame_idx
	
	back_spritesheet = back_tex
	back_frame = frame_idx
	front_texture = front_tex
	
	if clue_art:
		clue_art.texture = front_texture
	
	# Initial Hitbox Size (Matching the back texture)
	var back_size = Vector2(texture.get_width() / hframes, texture.get_height())
	hitbox.size = back_size
	hitbox.position = -back_size / 2
	
	anchor_point = start_pos
	global_position = start_pos
	bounds_rect = spawn_rect


func _process(delta):
	# update anchor when dragging
	if is_dragging:
		anchor_point = get_global_mouse_position() - drag_offset
	
	# float logic
	noise_time += delta * float_speed
	var noise_offset = Vector2(
		noise.get_noise_1d(noise_time) * float_range,
		noise.get_noise_1d(noise_time + 1000) * float_range
	)
	
	# card to card repulsion
	var separation_vector = Vector2.ZERO
	for other_card in get_tree().get_nodes_in_group("ghost_cards"):
		if other_card == self: continue
		var dist = global_position.distance_to(other_card.global_position)
		if dist < repulsion_radius:
			separation_vector += (global_position - other_card.global_position).normalized() * (repulsion_radius - dist)

	# border repulsion
	var border_vector = Vector2.ZERO
	if bounds_rect != Rect2():
		if global_position.x < bounds_rect.position.x + border_margin:
			border_vector.x += (bounds_rect.position.x + border_margin - global_position.x)
		elif global_position.x > bounds_rect.end.x - border_margin:
			border_vector.x -= (global_position.x - (bounds_rect.end.x - border_margin))
		if global_position.y < bounds_rect.position.y + border_margin:
			border_vector.y += (bounds_rect.position.y + border_margin - global_position.y)
		elif global_position.y > bounds_rect.end.y - border_margin:
			border_vector.y -= (global_position.y - (bounds_rect.end.y - border_margin))

	# combined movement
	var target_pos = anchor_point + noise_offset + (separation_vector * 0.1) + (border_vector * border_push_strength)
	
	# apply movement
	var current_lerp = 25.0 if is_dragging else repulsion_strength
	global_position = global_position.lerp(target_pos, delta * current_lerp)


func toggle_reveal(should_reveal: bool):
	if is_revealed == should_reveal: return
	is_revealed = should_reveal
	
	card_flip_audio_stream_player.pitch_scale = randf_range(0.9, 1.1)
	card_flip_audio_stream_player.play()

	var tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "rotation_degrees", 90 if is_revealed else 0, 0.4)
	tween.tween_property(self, "scale:x", 0.0, 0.2)
	
	tween.tween_callback(func(): 
		if is_revealed:
			self.self_modulate.a = 0.0
			
			if front_texture:
				var art_size = front_texture.get_size()
				hitbox.size = art_size
				hitbox.position = -art_size / 2
				mask_layer.size = art_size
				mask_layer.position = -art_size / 2
				mask_layer.visible = true
				card_frame.size = art_size
				card_frame.position = -art_size / 2
				card_frame.visible = true
				clue_art.position = art_size / 2
		else:
			self.self_modulate.a = 1.0
			texture = back_spritesheet
			hframes = 4
			frame = back_frame
			
			var back_size = Vector2(texture.get_width() / hframes, texture.get_height())
			hitbox.size = back_size
			hitbox.position = -back_size / 2
			mask_layer.visible = false
			card_frame.visible = false
	).set_delay(0.2)
	
	tween.tween_property(self, "scale:x", 1.0, 0.2).set_delay(0.2)


func _input(event):
	if not event is InputEventMouseButton:
		return

	var mouse_pos = get_global_mouse_position()
	var local_mouse = to_local(mouse_pos)
	var is_over = hitbox.get_rect().has_point(local_mouse)

	if event.pressed:
		if is_over:
			print("GHOST: Click detected on ", name)
			get_tree().set_group("ghost_cards", "z_index", 0)
			z_index = 10

			if event.button_index == MOUSE_BUTTON_LEFT:
				is_dragging = true
				drag_offset = mouse_pos - anchor_point
				get_viewport().set_input_as_handled()

			elif event.button_index == MOUSE_BUTTON_RIGHT:
				toggle_reveal(!is_revealed)
				get_viewport().set_input_as_handled()
	
	elif event.button_index == MOUSE_BUTTON_LEFT:
		if is_dragging:
			print("GHOST: Released card")
			is_dragging = false
