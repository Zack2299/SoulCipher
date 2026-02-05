extends Node2D

@export var card_scene: PackedScene = preload("uid://vod8bkhgu1tg")
@onready var spawn_zone_sprite: Sprite2D = $Sprite2D
@export var fixed_back: Texture2D = preload("uid://c0ewypdlrhiqr")
@export_dir var fronts_path: String = "res://assets/cards/clues/"

# control how far away from the sprite edges cards spawn
@export var padding: float = 100.0 

const NUM_CARDS: int = 6

var card_count = 0

var available_fronts: Array[Texture2D] = []

func _ready():
	# load the clue art once
	available_fronts = _load_textures_from_folder(fronts_path)
	available_fronts.shuffle()
	
	visibility_changed.connect(_on_visibility_changed)


func _on_visibility_changed():
	if visible:
		show_cards()


func show_cards():
	var sprite_pos = spawn_zone_sprite.global_position
	var sprite_size = spawn_zone_sprite.texture.get_size() * spawn_zone_sprite.scale
	
	# the actual bounding box in global space
	var spawn_rect = Rect2(sprite_pos - sprite_size / 2, sprite_size)
	
	var half_width = (sprite_size.x / 2) - padding
	var half_height = (sprite_size.y / 2) - padding

	for i in range(NUM_CARDS):
		card_count += 1
		if card_count > NUM_CARDS: break
		if available_fronts.is_empty():
			print("OUT OF CARDS")
			break
		
		var random_pos = Vector2(
			randf_range(sprite_pos.x - half_width, sprite_pos.x + half_width),
			randf_range(sprite_pos.y - half_height, sprite_pos.y + half_height)
		)
		
		var card = card_scene.instantiate()
		add_child(card)
		
		card.top_card_changed.connect(_on_top_card_changed)
		
		# pass spawn_rect to setup function
		card.setup(fixed_back, 0, available_fronts.pop_back(), random_pos, spawn_rect)


func _on_top_card_changed(card: Node):
	pass


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
