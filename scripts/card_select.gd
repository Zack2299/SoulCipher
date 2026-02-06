extends Node2D

@onready var spawn_zone_sprite: Sprite2D = $Sprite2D
@onready var confirm_button: TextureButton = $ConfirmButton

# control how far away from the sprite edges cards spawn
@export var padding: float = 100.0 

@export var card_scene: PackedScene = preload("uid://vod8bkhgu1tg")
@export var fixed_back: Texture2D = preload("uid://c0ewypdlrhiqr")

@export_dir var clues_path: String = "res://assets/cards/clues/"
@export_dir var weapons_path: String = "res://assets/cards/weapons/"
@export_dir var suspects_path: String = "res://assets/cards/suspects/"
@export_dir var locations_path: String = "res://assets/cards/locations/"

const NUM_CARDS: int = 6

var card_count = 0

var top_card: Card = null

var available_clues: Array[Texture2D] = []
var available_weapons: Array[Texture2D] = []
var available_suspects: Array[Texture2D] = []
var available_locations: Array[Texture2D] = []

func _ready():
	confirm_button.visible = false
	
	# load the art once
	available_clues = _load_textures_from_folder(clues_path)
	available_clues.shuffle()
	available_weapons = _load_textures_from_folder(weapons_path)
	available_weapons.shuffle()
	available_suspects = _load_textures_from_folder(suspects_path)
	available_suspects.shuffle()
	available_locations = _load_textures_from_folder(locations_path)
	available_locations.shuffle()
	
	visibility_changed.connect(_on_visibility_changed)


func _on_visibility_changed():
	if visible:
		show_cards()


func show_cards():
	for i in range(NUM_CARDS):
		card_count += 1
		if card_count > NUM_CARDS: break
		if available_clues.is_empty():
			available_clues = _load_textures_from_folder(clues_path)
			available_clues.shuffle()
		
		add_card(0)
	
	add_card(3)


func add_card(card_type: int):
	var sprite_pos = spawn_zone_sprite.global_position
	var sprite_size = spawn_zone_sprite.texture.get_size() * spawn_zone_sprite.scale
	
	# the actual bounding box in global space
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
	
	var available_fronts
	if card_type == 0:
		available_fronts = available_clues
	elif card_type == 1:
		available_fronts = available_weapons
	elif card_type == 2:
		available_fronts = available_suspects
	elif card_type == 3:
		available_fronts = available_locations
	
	# pass spawn_rect to setup function
	card.setup(fixed_back, card_type, available_fronts.pop_back(), random_pos, spawn_rect)


func _on_top_card_changed(card: Card):
	if card.card_type > 0:
		confirm_button.visible = false
		
		#if top_card:
			#top_card.modulate.a = 1
			#top_card = null
		return

	#card.modulate.a = 0.5
	top_card = card
	confirm_button.visible = true


func _load_textures_from_folder(path: String) -> Array[Texture2D]:
	var textures: Array[Texture2D] = []
	var dir = DirAccess.open(path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if !dir.current_is_dir() and (file_name.ends_with(".png")):
				var full_path = path.path_join(file_name)
				var tex = load(full_path)
				if tex is Texture2D:
					textures.append(tex)
			file_name = dir.get_next()
	return textures
