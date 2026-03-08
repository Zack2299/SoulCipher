extends Node2D

enum CardType { GHOST, WEAPON, SUSPECT, LOCATION }

@onready var spawn_zone_sprite: Sprite2D = $Sprite2D
@onready var confirm_button: TextureButton = $ConfirmButton
@onready var confirm_audio_stream_player: AudioStreamPlayer = $ConfirmAudioStreamPlayer

@export var padding: float = 100.0 
@export var card_scene: PackedScene = preload("res://entities/ghost_card/ghost_card.tscn")
@export var fixed_back: Texture2D = preload("uid://c0ewypdlrhiqr")

@export_dir var clues_path: String = "res://assets/cards/clues/"
@export_dir var weapons_path: String = "res://assets/cards/weapons/"
@export_dir var suspects_path: String = "res://assets/cards/suspects/"
@export_dir var locations_path: String = "res://assets/cards/locations/"

const NUM_GHOST_CARDS: int = 7

var current_phase: int = CardType.WEAPON
var top_card: Card = null
var current_type_card: Card = null
var can_press_select: bool = true

# these persist for entire game session
var available_clues: Array[Texture2D] = []
var available_weapons: Array[Texture2D] = []
var available_suspects: Array[Texture2D] = []
var available_locations: Array[Texture2D] = []


func _ready():
	confirm_button.visible = false
	confirm_button.pressed.connect(_on_confirm_pressed)
	
	available_clues = _load_textures(clues_path)
	available_weapons = _load_textures(weapons_path)
	available_suspects = _load_textures(suspects_path)
	available_locations = _load_textures(locations_path)
	

func start():
	if multiplayer.get_unique_id() != GameManager.ghost_id:
		return
	
	_shuffle_all()
	_broadcast_crystal_ball_data()
	
	# spawn the very first n-1 clues (visibility change spawns the nth clue)
	for i in range(NUM_GHOST_CARDS - 1):
		add_card(CardType.GHOST, available_clues.pop_front())
	
	visibility_changed.connect(_on_visibility_changed)


func _broadcast_crystal_ball_data():
	# extract the texture paths for the first N cards of each type
	var s_paths = _get_paths_slice(available_suspects, GameManager.num_cards)
	var w_paths = _get_paths_slice(available_weapons, GameManager.num_cards)
	var l_paths = _get_paths_slice(available_locations, GameManager.num_cards)
	
	# broadcast to everyone
	sync_crystal_ball_options.rpc(s_paths, w_paths, l_paths)


# helper to get resource paths from array of textures
func _get_paths_slice(tex_array: Array[Texture2D], count: int) -> Array[String]:
	var paths: Array[String] = []
	var limit = min(count, tex_array.size())
	for i in range(limit):
		paths.append(tex_array[i].resource_path)
	paths.shuffle() # randomize so you don't just guess the first 3 every time
	return paths


@rpc("authority", "call_local", "reliable") 
func refresh_cards():
	if multiplayer.get_unique_id() != GameManager.ghost_id: return
	
	# REMOVE OLD CARDS
	var removal_tween = create_tween().set_parallel(true)
	var cards_to_remove: Array[Node] = []

	for child in get_children():
		if child.has_method("setup"): 
			if child.card_type == CardType.GHOST:
				# don't delete held or type card
				if child != top_card and child != current_type_card:
					cards_to_remove.append(child)
					
					# shrink and fade
					removal_tween.tween_property(child, "scale", Vector2.ZERO, 0.25)\
						.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
					removal_tween.tween_property(child, "modulate:a", 0.0, 0.25)

	if not cards_to_remove.is_empty():
		await removal_tween.finished
		for card in cards_to_remove:
			if is_instance_valid(card):
				card.burn_card()

	# SPAWN NEW CARDS
	var cards_needed = NUM_GHOST_CARDS
	
	if top_card != null:
		cards_needed -= 1
		
	var spawn_tween = create_tween().set_parallel(true)
		
	for i in range(cards_needed):
		if available_clues.size() > 0:
			var new_card = add_card(CardType.GHOST, available_clues.pop_front())
			
			new_card.scale = Vector2.ZERO
			new_card.modulate.a = 0.0
			
			var delay = i * 0.08
			
			# pop up
			spawn_tween.tween_property(new_card, "scale", Vector2(1.0, 1.0), 0.4)\
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)\
				.set_delay(delay)
				
			# fade in
			spawn_tween.tween_property(new_card, "modulate:a", 1.0, 0.3)\
				.set_delay(delay)



@rpc("any_peer", "call_local", "reliable")
func sync_crystal_ball_options(s_paths: Array, w_paths: Array, l_paths: Array):
	var crystal_ball = get_tree().root.find_child("CrystalBallRoomUI", true, false)
	
	if crystal_ball and crystal_ball.has_method("setup_crystal_ball"):
		crystal_ball.setup_crystal_ball(s_paths, w_paths, l_paths)
	else:
		push_warning("CrystalBall node not found to sync options!")


func _on_visibility_changed():
	if visible:
		current_phase = CardType.WEAPON
		if multiplayer.get_unique_id() == GameManager.ghost_id:
			_proceed_to_next_available_phase()


@rpc("any_peer", "call_local", "reliable")
func sync_ghost_phase(new_phase: int):
	current_phase = new_phase


func _proceed_to_next_available_phase():
	if multiplayer.get_unique_id() != GameManager.ghost_id:
		return
	var category_name = GameManager._get_category_string(current_phase)
	
	# if this part of the case is already solved, skip it
	if category_name in GameManager.solved_categories_in_current_track:
		current_phase += 1
		if multiplayer.get_unique_id() == GameManager.ghost_id:
			rpc("sync_ghost_phase", current_phase)
		if current_phase > CardType.LOCATION:
			_end_ghost_selection()
		else:
			_proceed_to_next_available_phase()
		return
	rpc("sync_ghost_phase", current_phase)
	# if not solved, set up the board for this phase
	_setup_ghost_selection_ui()

func _setup_ghost_selection_ui():
	var category_name = GameManager._get_category_string(current_phase)
	var target_path = GameManager.current_targets[GameManager.current_track][category_name]
	
	# ghost always provided a new clue
	add_card(CardType.GHOST, available_clues.pop_front())
	
	var target_texture: Texture2D
	if target_path != "":
		# target card remains same from the failed round
		target_texture = load(target_path)
	else:
		# pop a brand new target card for this track
		match current_phase:
			CardType.WEAPON: target_texture = available_weapons.pop_front()
			CardType.SUSPECT: target_texture = available_suspects.pop_front()
			CardType.LOCATION: target_texture = available_locations.pop_front()
		
		# save it so server knows what the target is
		GameManager.current_targets[GameManager.current_track][category_name] = target_texture.resource_path

	current_type_card = add_card(current_phase, target_texture)
	can_press_select = true


func _on_selection_confirmed():
	current_phase += 1
	if current_phase > CardType.LOCATION:
		_end_ghost_selection()
	else:
		_proceed_to_next_available_phase()


func _end_ghost_selection():
	if multiplayer.get_unique_id() == GameManager.ghost_id:
		GameManager.world_node.request_phase_change.rpc_id(1, "ghost_turn_over")


func add_card(type: int, texture: Texture2D) -> Card:
	if texture == null: return null # safety check for empty decks
	
	var sprite_pos = spawn_zone_sprite.global_position
	var sprite_size = spawn_zone_sprite.texture.get_size() * spawn_zone_sprite.scale
	var spawn_rect = Rect2(sprite_pos - sprite_size / 2, sprite_size)
	
	var half_width = (sprite_size.x / 2) - padding
	var half_height = (sprite_size.y / 2) - padding
	
	var random_pos = Vector2(
		randf_range(sprite_pos.x - half_width, sprite_pos.x + half_width),
		randf_range(sprite_pos.y - half_height, sprite_pos.y + half_height)
	)
	
	var card = card_scene.instantiate()
	add_child(card)
	card.top_card_changed.connect(_on_top_card_changed)
	card.setup(fixed_back, type, texture, random_pos, spawn_rect)
	return card


func _on_top_card_changed(card: Card):
	if card.card_type != CardType.GHOST:
		confirm_button.visible = false
		return
	top_card = card
	confirm_button.visible = true
	confirm_button.disabled = false


func _on_confirm_pressed():
	if not top_card or not current_type_card or not can_press_select: return
	can_press_select = false
	
	confirm_button.disabled = true
	confirm_button.visible = false
	
	confirm_audio_stream_player.play()
	
	# get the texture paths to send to other players
	var ghost_tex_path = top_card.front_texture.resource_path
	var type_tex_path = current_type_card.front_texture.resource_path
	
	# we still need the NodePaths ONLY for the Ghost to animate their removal
	var ghost_node = top_card.get_path()
	var type_node = current_type_card.get_path()
	
	sync_card_selection.rpc(ghost_tex_path, type_tex_path, ghost_node, type_node, current_phase)


@rpc("any_peer", "call_local", "reliable")
func sync_card_selection(g_tex_path: String, t_tex_path: String, g_node_path: NodePath, t_node_path: NodePath, phase: int):
	GameManager.record_selection(
		GameManager.current_track, 
		phase, 
		t_tex_path,
		g_tex_path
	)
	
	if multiplayer.is_server():
		# purge rooms deleted by mansion generator (orphaned rooms)
		GameManager.world_node.card_spawn_rooms = GameManager.world_node.card_spawn_rooms.filter(func(r): return is_instance_valid(r))
		
		var valid_rooms = GameManager.world_node.card_spawn_rooms
		
		if not valid_rooms.is_empty():
			var target_room = valid_rooms.pick_random()
			var room_idx = GameManager.world_node.rooms_array.find(target_room)
			
			GameManager.world_node.card_spawn_rooms.erase(target_room)
			
			spawn_clue_for_all.rpc(g_tex_path, room_idx, phase)

	var g_card = get_node_or_null(g_node_path)
	var t_card = get_node_or_null(t_node_path)
	
	if g_card and t_card:
		confirm_button.visible = false
		await _animate_removal(g_card)
		await _animate_removal(t_card)
	
	_on_selection_confirmed()


@rpc("authority", "call_local", "reliable")
func spawn_clue_for_all(tex_path: String, room_idx: int, type_index: int):
	GameManager.world_node.spawn_clue_in_specific_room(tex_path, type_index, room_idx)


func _animate_removal(card: Card):
	if not card: return
	var tween = create_tween().set_parallel(true)
	tween.tween_property(card, "modulate:a", 0.0, 1.0).set_ease(Tween.EASE_IN_OUT).set_delay(0.4)
	#tween.tween_property(card, "scale", Vector2(0.5,0.5), 2.0)
	#await tween.finished
	await card.burn_card()


func _load_textures(path: String) -> Array[Texture2D]:
	var textures: Array[Texture2D] = []
	var dir = DirAccess.open(path)
	
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		
		while file_name != "":
			if not dir.current_is_dir() and not file_name.begins_with("."):
				# handle exported builds
				if file_name.ends_with(".import"):
					file_name = file_name.replace(".import", "")
				
				# filter for images
				if file_name.ends_with(".png"):
					var full_path = path.path_join(file_name)
					
					# avoid duplicates in editor
					var tex = load(full_path)
					if tex is Texture2D and not textures.has(tex):
						textures.append(tex)
			
			file_name = dir.get_next()
	else:
		push_error("Failed to open directory: " + path)
		
	return textures


func _shuffle_all():
	available_clues.shuffle()
	available_weapons.shuffle()
	available_suspects.shuffle()
	available_locations.shuffle()
