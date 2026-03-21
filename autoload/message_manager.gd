extends CanvasLayer

var message_scene = preload("uid://bk22f4cvnw8u")

@onready var container: VBoxContainer = $VBoxContainer


func _ready() -> void:
	layer = 100
	
	#container.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, 20)
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE


func send(text: String, type: String = "info"):
	var msg = message_scene.instantiate()
	container.add_child(msg)
	
	var color = Color.WHITE
	match type:
		"error": color = Color.RED
		"success": color = Color.GREEN
		"warning": color = Color.YELLOW
	
	msg.set_message(text, color)
