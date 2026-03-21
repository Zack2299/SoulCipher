extends CanvasLayer

var message_scene = preload("uid://bk22f4cvnw8u")

@onready var container: VBoxContainer = $VBoxContainer


func _ready() -> void:
	layer = 100
	
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE


func send(text: String, type: String = "info"):
	var msg = message_scene.instantiate()
	container.add_child(msg)
	
	var color = Color.WHITE
	match type:
		"error": color = Color.RED
		"success": color = Color.GREEN
		"warning": color = Color.YELLOW
		"weapon": color = Color.FIREBRICK
		"suspect": color = Color.SKY_BLUE
		"location": color = Color("9d2effff") # purple
		"ghost": color = Color.LIGHT_SEA_GREEN
	
	msg.set_message(text, color)


@rpc("authority", "call_local", "reliable")
func send_to_others(text: String, type: String, exclude_id: int):
	if multiplayer.get_unique_id() == exclude_id:
		return
		
	send(text, type)


func kill_all_messages():
	for child in container.get_children():
		child.queue_free()
