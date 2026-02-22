extends Node2D

enum ShopItemType { WEAPON, SUSPECT, LOCATION, \
	REFRESH_CARDS, PAUSE_TIMER, PLACE_CLUE, \
	MAP_CRYSTAL_BALL, MAP_CARDS, MAP_COINS }

@onready var item_sprite: Sprite2D = $ItemSprite
@onready var item_text: Label = $ItemText
@onready var cost_text: Label = $CostText

@export var item_type: ShopItemType
var cost: int

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	_setup_item_data()
	
func _setup_item_data():
	match item_type:
		ShopItemType.WEAPON:
			item_sprite.texture = preload("uid://n6c07acjclp8")
			item_text.text = "Dull The Blade:\n\nThe spirits strike an incorrect weapon from the record."
			cost = 10
			
		ShopItemType.SUSPECT:
			item_sprite.texture = preload("uid://dv54d0hxegfp")
			item_text.text = "Alibi Revealed:\n\nThe spirits eliminate one innocent suspect from your investigation."
			cost = 10
			
		ShopItemType.LOCATION:
			item_sprite.texture = preload("uid://8aohoy5n604c")
			item_text.text = "Hollow Ground:\n\nAn incorrect location is permanently crossed off your list."
			cost = 10
			
		ShopItemType.REFRESH_CARDS:
			item_sprite.texture = preload("uid://baocy0hfwvspi")
			item_text.text = "Ethereal Shuffle:\n\nGrants the Ghost the power to redraw their hand of visions."
			cost = 7
			
		ShopItemType.PAUSE_TIMER:
			item_sprite.texture = preload("uid://diup458y4coja")
			item_text.text = "Borrowed Time:\n\nHalt the clock for 30 seconds at the beginning of the next round."
			cost = 5
			
		ShopItemType.PLACE_CLUE:
			item_sprite.texture = preload("uid://3ywk123annse")
			item_text.text = "Phantom Mark:\n\nThe Ghost places a spectral ring over an object, leaving a visual hint for a clue card."
			cost = 12
			
		ShopItemType.MAP_CRYSTAL_BALL:
			item_sprite.texture = preload("uid://fld5geybr25h")
			item_text.text = "Astral Projection:\n\nYour minimap reveals the path to the Crystal Ball room for a single round."
			cost = 5
			
		ShopItemType.MAP_CARDS:
			item_sprite.texture = preload("uid://be36fxa446r86")
			item_text.text = "All-Seeing Eye:\n\nThe exact locations of all clue cards of the next round are illuminated on the map."
			cost = 20
			
		ShopItemType.MAP_COINS:
			item_sprite.texture = preload("uid://tukd6yhemyu1")
			item_text.text = "Midas Gaze:\n\nThe minimap reveals the glint of all hidden coins in the mansion for the next round."
			cost = 10
			
	cost_text.text = str(cost)
