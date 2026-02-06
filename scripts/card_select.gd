extends Node2D

enum CardType { GHOST, WEAPON, SUSPECT, LOCATION }

@onready var spawn_zone_sprite: Sprite2D = $Sprite2D
@onready var confirm_button: TextureButton = $ConfirmButton

@export var padding: float = 100.0 
@export var card_scene: PackedScene = preload("uid://vod8bkhgu1tg")
@export var fixed_back: Texture2D = preload("uid://c0ewypdlrhiqr")

@export_dir var clues_path: String = "res://assets/cards/clues/"
@export_dir var weapons_path: String = "res://assets/cards/weapons/"
@export_dir var suspects_path: String = "res://assets/cards/suspects/"
@export_dir var locations_path: String = "res://assets/cards/locations/"

const NUM_GHOST_CARDS: int = 6

var current_phase: int = CardType.WEAPON
var top_card: Card = null
var current_type_card: Card = null

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
	
	_shuffle_all()
	
	# spawn the very first 6 ghost cards
	for i in range(NUM_GHOST_CARDS):
		add_card(CardType.GHOST, available_clues.pop_back())
	
	visibility_changed.connect(_on_visibility_changed)


func _on_visibility_changed():
	if visible:		
		current_phase = CardType.WEAPON
		
		current_type_card = add_card(CardType.WEAPON, available_weapons.pop_back())


func add_card(type: int, tex: Texture2D) -> Card:
	if tex == null: return null # Safety check for empty decks
	
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
	card.setup(fixed_back, type, tex, random_pos, spawn_rect)
	return card


func _on_top_card_changed(card: Card):
	if card.card_type != CardType.GHOST:
		confirm_button.visible = false
		return
	top_card = card
	confirm_button.visible = true


func _on_confirm_pressed():
	if not top_card or not current_type_card: return
	sync_card_selection.rpc(top_card.get_path(), current_type_card.get_path())


@rpc("any_peer", "call_local", "reliable")
func sync_card_selection(ghost_node_path: NodePath, type_node_path: NodePath):
	var g_card = get_node_or_null(ghost_node_path)
	var t_card = get_node_or_null(type_node_path)
	
	confirm_button.visible = false
	
	# animate removal of selected ghost card and current phase card
	await _animate_removal(g_card)
	await _animate_removal(t_card)
	
	current_phase += 1
	
	if current_phase > CardType.LOCATION:
		# end of ghost's turn for this round
		if multiplayer.is_server():
			GameManager.world_node.request_phase_change.rpc("ghost_turn_over")
	else:
		# immediately replace the ghost card so there are always 6
		add_card(CardType.GHOST, available_clues.pop_back())
		
		# add the next target card for the next phase
		var next_tex: Texture2D
		match current_phase:
			CardType.SUSPECT: next_tex = available_suspects.pop_back()
			CardType.LOCATION: next_tex = available_locations.pop_back()
			
		current_type_card = add_card(current_phase, next_tex)


func _animate_removal(card: Card):
	if not card: return
	var tween = create_tween().set_parallel(true)
	tween.tween_property(card, "modulate:a", 0.0, 0.4)
	tween.tween_property(card, "scale", Vector2.ZERO, 0.4)
	await tween.finished
	card.queue_free()


func _load_textures(path: String) -> Array[Texture2D]:
	var textures: Array[Texture2D] = []
	var dir = DirAccess.open(path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if !dir.current_is_dir() and file_name.ends_with(".png"):
				var tex = load(path.path_join(file_name))
				if tex is Texture2D: textures.append(tex)
			file_name = dir.get_next()
	return textures


func _shuffle_all():
	available_clues.shuffle()
	available_weapons.shuffle()
	available_suspects.shuffle()
	available_locations.shuffle()
