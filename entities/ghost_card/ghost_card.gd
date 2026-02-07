class_name Card
extends Sprite2D

signal card_selected

@onready var hitbox: ColorRect = $Hitbox
@onready var mask_layer: NinePatchRect = $MaskLayer
@onready var clue_art: Sprite2D = $MaskLayer/ClueArt
@onready var card_frame: NinePatchRect = $CardFrame
@onready var card_flip_audio_stream_player: AudioStreamPlayer = $CardFlipAudioStreamPlayer

# config
var front_texture: Texture2D
var back_spritesheet: Texture2D = preload("uid://c0ewypdlrhiqr")
var back_frame: int
var is_revealed: bool = false
var anchor_point: Vector2
var bounds_rect: Rect2
var card_type: int

signal top_card_changed
var top_card = null:
	set(value):
		top_card = value
		if top_card != null:
			top_card_changed.emit(self)

# dragging variables
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
@export var border_margin: float = 50.0
@export var border_push_strength: float = 3.0


func _ready():
	add_to_group("ghost_cards")
	noise.seed = randi()
	noise.frequency = 0.01
	centered = true
	
	mask_layer.visible = false
	card_frame.visible = false
	
	if front_texture:
		self.name = front_texture.resource_path.get_file().get_basename()


func setup(back_tex: Texture2D, frame_idx: int, front_tex: Texture2D, start_pos: Vector2, spawn_rect: Rect2):
	texture = back_tex
	hframes = 4  
	frame = frame_idx
	card_type = frame_idx
	if card_type == 0:
		card_frame.texture = preload("uid://c0c7brf3376vl")
	elif card_type == 1:
		card_frame.texture = preload("uid://240yaag32lqm")
	elif card_type == 2:
		card_frame.texture = preload("uid://cnfs0t5f87raw")
	elif card_type == 3:
		card_frame.texture = preload("uid://wyg3wb5uxx4b")
	
	back_spritesheet = back_tex
	back_frame = frame_idx
	front_texture = front_tex
	
	if clue_art:
		clue_art.texture = front_texture
	
	# initial hitbox size (matching the back texture)
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
	if not is_visible_in_tree():
		return
	
	if not event is InputEventMouseButton:
		return

	var mouse_pos = get_global_mouse_position()
	var local_mouse = to_local(mouse_pos)
	var is_over = hitbox.get_rect().has_point(local_mouse)

	if event.pressed:
		# check if we are over the card AND if we are the highest Z-index under the mouse
		if is_over and _is_top_card():
			var cards = get_tree().get_nodes_in_group("ghost_cards")
			for card in cards:
				# lower everyone by 1 -- keeps relative order but makes room for the new 10
				card.z_index = max(0, card.z_index - 1)
				
			# put this card on top (next top one has z_index of 9)
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
			is_dragging = false


# helper function to find if this card is visually on top
func _is_top_card() -> bool:
	var mouse_pos = get_global_mouse_position()
	var cards = get_tree().get_nodes_in_group("ghost_cards")
	
	var max_z = z_index
	
	for card in cards:
		# check if the other card is also under the mouse
		if card.hitbox.get_rect().has_point(card.to_local(mouse_pos)):
			# if the other card has a higher Z, or same Z but is later in the tree
			if card.z_index > max_z:
				return false
			elif card.z_index == max_z and card.get_index() > get_index():
				# this handles cards with the same Z-index (standard tree order)
				return false
				
	top_card = self
	return true
