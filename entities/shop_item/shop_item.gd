extends Node2D

enum ShopItemType { WEAPON, SUSPECT, LOCATION, \
	REFRESH_CARDS, PAUSE_TIMER, PLACE_CLUE, \
	MAP_CRYSTAL_BALL, MAP_CARDS, MAP_COINS }

signal purchase_requested(item_node: Node2D)

@onready var item_sprite: Sprite2D = $ItemSprite
@onready var item_text: Label = $ItemText
@onready var cost_text: Label = $CostText
@onready var click_area: Area2D = $ClickArea

@export var item_type: ShopItemType
var cost: int
var slot_index: int = -1

var is_hovered: bool = false
var is_purchased: bool = false
var original_position: Vector2
var shake_tween: Tween
var hover_tween: Tween

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	_setup_item_data()
	
	original_position = position
	position.y += 300
	modulate.a = 0.0 
	
	var tween = create_tween().set_parallel(true)
	tween.tween_property(self, "position:y", original_position.y, 2.0).set_trans(Tween.TRANS_CIRC).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 1.0, 0.3)
	
	click_area.mouse_entered.connect(_on_mouse_entered)
	click_area.mouse_exited.connect(_on_mouse_exited)
	click_area.input_event.connect(_on_input_event)


func _setup_item_data():
	match item_type:
		ShopItemType.WEAPON:
			item_sprite.texture = preload("uid://n6c07acjclp8")
			item_text.text = "Dull The Blade:\n\nThe spirits strike an incorrect weapon from the record."
			cost = 10
			
		ShopItemType.SUSPECT:
			item_sprite.texture = preload("uid://dv54d0hxegfp")
			item_text.text = "Alibi Revealed:\n\nThe spirits eliminate one innocent suspect from your list."
			cost = 10
			
		ShopItemType.LOCATION:
			item_sprite.texture = preload("uid://8aohoy5n604c")
			item_text.text = "Hollow Ground:\n\nAn incorrect location is permanently crossed off your list."
			cost = 10
			
		ShopItemType.REFRESH_CARDS:
			item_sprite.texture = preload("uid://baocy0hfwvspi")
			item_text.text = "Ethereal Shuffle:\n\nGrants the Ghost the power to redraw their hand of visions."
			cost = 12
			
		ShopItemType.PAUSE_TIMER:
			item_sprite.texture = preload("uid://dhpdhj80826uf")
			item_text.text = "Borrowed Time:\n\nFreeze the clock for 60 seconds at the beginning of the next round."
			cost = 3
			
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
			cost = 10
			
		ShopItemType.MAP_COINS:
			item_sprite.texture = preload("uid://tukd6yhemyu1")
			item_text.text = "Midas Gaze:\n\nThe minimap reveals the glint of all hidden coins in the mansion for the next round."
			cost = 5
	
	cost *= GameManager.cost_multiplier
	cost_text.text = str(cost)


func _on_mouse_entered():
	if is_purchased: return
	if GameManager.world_node.player_card_screen_is_shown: return
	is_hovered = true
	Cursor.is_hovering = true
	_update_visual_state()


func _on_mouse_exited():
	if is_purchased: return
	is_hovered = false
	Cursor.is_hovering = false
	_update_visual_state()


# guarantees the card always knows what size and color it should be
func _update_visual_state():
	if hover_tween and hover_tween.is_valid():
		hover_tween.kill()
		
	hover_tween = create_tween().set_parallel(true)
	
	if is_hovered:
		hover_tween.tween_property(self, "scale", Vector2(1.05, 1.05), 0.1)
		hover_tween.tween_property(self, "modulate", Color(1.2, 1.2, 1.2), 0.1)
	else:
		hover_tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.1)
		hover_tween.tween_property(self, "modulate", Color(1.0, 1.0, 1.0), 0.1)


func _on_input_event(_viewport, event, _shape_idx):
	if is_purchased: return
	
	if GameManager.world_node.player_card_screen_is_shown: return
	
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		purchase_requested.emit(self)


func confirm_purchase():
	is_purchased = true
	Cursor.is_hovering = false
	
	if hover_tween and hover_tween.is_valid(): hover_tween.kill()
	if shake_tween and shake_tween.is_valid(): shake_tween.kill()
	
	modulate = Color.WHITE 
	var tween = create_tween()
	
	tween.tween_property(self, "scale", Vector2(1.15, 1.15), 0.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.chain().tween_property(self, "scale", Vector2(0.9, 0.9), 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(self, "modulate:a", 0.5, 0.25) 


func reject_purchase():
	if shake_tween and shake_tween.is_valid():
		shake_tween.kill()
		
	position.x = original_position.x
	shake_tween = create_tween()
	shake_tween.tween_property(self, "position:x", original_position.x + 12, 0.05)
	shake_tween.tween_property(self, "position:x", original_position.x - 12, 0.05)
	shake_tween.tween_property(self, "position:x", original_position.x + 6, 0.05)
	shake_tween.tween_property(self, "position:x", original_position.x, 0.05)
	
	if hover_tween and hover_tween.is_valid():
		hover_tween.kill()
		
	hover_tween = create_tween()
	modulate = Color(1.5, 0.5, 0.5)
	
	# hold red flash, then check where the mouse is
	hover_tween.tween_interval(0.15)
	hover_tween.tween_callback(_update_visual_state)
