extends Sprite2D

signal card_selected

# config
var front_texture: Texture2D
var back_spritesheet: Texture2D = preload("uid://c0ewypdlrhiqr")
var back_frame: int
var is_revealed: bool = false
var anchor_point: Vector2
var bounds_rect: Rect2

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
@export var repulsion_strength: float = 5
@export var border_margin: float = 0
@export var border_push_strength: float = 3.0

func _ready():
	add_to_group("ghost_cards")
	noise.seed = randi()
	noise.frequency = 0.01
	# make sure pivot is centered for rotation and scaling
	if texture:
		centered = true

func setup(back_tex: Texture2D, frame_idx: int, front_tex: Texture2D, start_pos: Vector2, spawn_rect: Rect2):
	texture = back_tex
	hframes = 4  
	frame = frame_idx
	
	back_spritesheet = back_tex
	back_frame = frame_idx
	front_texture = front_tex
	
	anchor_point = start_pos
	global_position = start_pos
	bounds_rect = spawn_rect

func _process(delta):
	if is_dragging:
		anchor_point = get_global_mouse_position() - drag_offset
	
	noise_time += delta * float_speed
	var noise_offset = Vector2(
		noise.get_noise_1d(noise_time) * float_range,
		noise.get_noise_1d(noise_time + 1000) * float_range
	)
	
	var separation_vector = Vector2.ZERO
	for other_card in get_tree().get_nodes_in_group("ghost_cards"):
		if other_card == self: continue
		var dist = global_position.distance_to(other_card.global_position)
		if dist < repulsion_radius:
			separation_vector += (global_position - other_card.global_position).normalized() * (repulsion_radius - dist)

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

	var target_pos = anchor_point + noise_offset + (separation_vector * 0.1) + (border_vector * border_push_strength)
	var lerp_speed = delta * 25.0 if is_dragging else delta * repulsion_strength
	global_position = global_position.lerp(target_pos, lerp_speed)

func toggle_reveal(should_reveal: bool):
	if is_revealed == should_reveal: return
	is_revealed = should_reveal
	
	var tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	
	tween.tween_property(self, "rotation_degrees", 90 if is_revealed else 0, 0.4)
	
	tween.tween_property(self, "scale:x", 0.0, 0.2)
	
	# midpoint swap textures
	tween.tween_callback(func(): 
		if is_revealed:
			texture = front_texture
			hframes = 1 
			frame = 0
		else:
			texture = back_spritesheet
			hframes = 4
			frame = back_frame
	).set_delay(0.2)
	
	# 4. Second half of the flip: Scale X back to 1 (Delayed by 0.2s)
	tween.tween_property(self, "scale:x", 1.0, 0.2).set_delay(0.2)

func _input(event):
	var mouse_pos = get_global_mouse_position()
	# check if mouse is within the sprite's bounds
	var is_over_card = get_rect().has_point(to_local(mouse_pos))
	
	if event is InputEventMouseButton:
		if is_over_card and event.pressed:
			# --- Z-ORDER MANAGEMENT ---
			# Reset all cards to base layer, pop this one to the front
			get_tree().set_group("ghost_cards", "z_index", 0)
			z_index = 10

			# --- LEFT CLICK (Drag) ---
			if event.button_index == MOUSE_BUTTON_LEFT:
				is_dragging = true
				drag_offset = mouse_pos - anchor_point
				get_viewport().set_input_as_handled()

			# --- RIGHT CLICK (Toggle Reveal) ---
			if event.button_index == MOUSE_BUTTON_RIGHT:
				toggle_reveal(!is_revealed)
				get_viewport().set_input_as_handled()

		# --- RELEASE DRAG ---
		if event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			if is_dragging:
				is_dragging = false
