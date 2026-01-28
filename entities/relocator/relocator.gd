extends Node

@export var scene_to_switch_to: PackedScene
@export var change_scene_to_packed: bool = false

@onready var sprite_2d: Sprite2D = $Sprite2D

var relocator_hovered = false

func _on_clickable_area_mouse_entered_clickable_area() -> void:
	sprite_2d.frame = 1
	relocator_hovered = true

func _on_clickable_area_mouse_exited_clickable_area() -> void:
	sprite_2d.frame = 0
	relocator_hovered = false

func _process(delta: float) -> void:
	if relocator_hovered and Input.is_action_just_pressed("click"):
		Cursor.is_hovering = false
		spawn_and_switch()

func spawn_and_switch() -> void:
	if not scene_to_switch_to:
		print("No scene assigned!")
		return
	
	# completely changes scene (so destroys current scene and switches)
	# (for titlescreen)
	if change_scene_to_packed:
		get_tree().change_scene_to_packed(scene_to_switch_to)
	else: # otherwise just change visibility rather than destroying
		scene_to_switch_to.visible = true
		get_parent().visible = false
	
