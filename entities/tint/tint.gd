extends ColorRect

@onready var card_select: Node2D = $"../../CardSelect"

func _ready() -> void:
	card_select.visibility_changed.connect(_on_card_select_visibility_changed)

	_on_card_select_visibility_changed()

func _on_card_select_visibility_changed() -> void:
	visible = !card_select.visible
