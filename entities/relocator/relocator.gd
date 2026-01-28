extends Node

@export var scene_to_spawn: PackedScene
@export var scene_parent: Node

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
		spawn_and_switch()

func spawn_and_switch() -> void:
	if not scene_to_spawn:
		print("No scene assigned!")
		return
	
	get_tree().change_scene_to_packed(scene_to_spawn)
