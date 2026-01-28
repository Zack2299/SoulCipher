extends Node

@export var area_2d: Area2D

@export_group("Tween Enter Settings")
@export var hover_scale: Vector2 = Vector2(1.2, 1.2)
@export var enter_duration: float = 0.25
@export var enter_trans: Tween.TransitionType = Tween.TRANS_CUBIC
@export var enter_ease: Tween.EaseType = Tween.EASE_OUT

@export_group("Tween Exit Settings")
@export var exit_duration: float = 0.5
@export var exit_trans: Tween.TransitionType = Tween.TRANS_ELASTIC
@export var exit_ease: Tween.EaseType = Tween.EASE_OUT

@onready var parent: Node2D = get_parent()

var tween: Tween

func _ready() -> void:
	if not parent is Node2D:
		push_warning("HoverComponent: Parent must be a Node2D.")
		return
		
	area_2d.mouse_entered.connect(_on_mouse_entered)
	area_2d.mouse_exited.connect(_on_mouse_exited)

func _on_mouse_entered() -> void:
	animate(hover_scale, enter_duration, enter_trans, enter_ease)

func _on_mouse_exited() -> void:
	animate(Vector2.ONE, exit_duration, exit_trans, exit_ease)

func animate(target_scale: Vector2, duration: float, trans: Tween.TransitionType, easing: Tween.EaseType) -> void:
	if tween:
		tween.kill()
	
	tween = create_tween().set_trans(trans).set_ease(easing)
	
	tween.tween_property(parent, "scale", target_scale, duration)
