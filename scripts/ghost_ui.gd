extends CanvasLayer

@onready var place_clue_button: TextureButton = $HBoxContainer/PlaceClueButton
@onready var refresh_cards_button: TextureButton = $HBoxContainer/RefreshCardsButton
@onready var place_clue_label: Label = $HBoxContainer/PlaceClueButton/PlaceClueLabel
@onready var refresh_cards_label: Label = $HBoxContainer/RefreshCardsButton/RefreshCardsLabel


func _ready():
	refresh_cards_button.visible = false
	place_clue_button.visible = false
	
	refresh_cards_button.pressed.connect(_on_refresh_pressed)
	place_clue_button.pressed.connect(_on_place_clue_pressed)
	
	refresh_cards_button.mouse_entered.connect(func(): Cursor.is_hovering = true)
	refresh_cards_button.mouse_exited.connect(func(): Cursor.is_hovering = false)
	
	place_clue_button.mouse_entered.connect(func(): Cursor.is_hovering = true)
	place_clue_button.mouse_exited.connect(func(): Cursor.is_hovering = false)


func _on_refresh_pressed():
	GameManager.request_consume_powerup.rpc_id(1, "refresh_cards")


func _on_place_clue_pressed():
	GameManager.request_consume_powerup.rpc_id(1, "place_clue")


func update_powerup_buttons(inventory: Dictionary):
	var refresh_count = inventory.get("refresh_cards", 0)
	var place_clue_count = inventory.get("place_clue", 0)
	
	refresh_cards_label.text = "x" + str(refresh_count)
	place_clue_label.text = "x" + str(place_clue_count)
	
	refresh_cards_button.visible = refresh_count > 0
	place_clue_button.visible = place_clue_count > 0
