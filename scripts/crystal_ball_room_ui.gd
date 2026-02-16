extends Node2D

enum TokenType { WEAPON, SUSPECT, LOCATION }

@onready var clickable_area: Node = $CrystalBall/ClickableArea
@onready var crystal_ball_above: Sprite2D = $CrystalBallAbove
#@onready var inside_crystal_ball: Sprite2D = $InsideCrystalBall
@onready var inside_crystal_ball: Node2D = $InsideCrystalBall
@onready var inside_crystal_ball_bg: Sprite2D = $InsideCrystalBall/InsideCrystalBallBg


@onready var left_clickable_area: Node = $InsideCrystalBall/LeftArrow/ClickableArea
@onready var right_clickable_area: Node = $InsideCrystalBall/RightArrow/ClickableArea
@onready var tokens: Sprite2D = $InsideCrystalBall/Tokens
@onready var token_audio_stream_player: AudioStreamPlayer = $TokenAudioStreamPlayer
@onready var chime_audio_stream_player: AudioStreamPlayer = $ChimeAudioStreamPlayer
@onready var button_audio_stream_player: AudioStreamPlayer = $ButtonAudioStreamPlayer
@onready var area_2d: Area2D = $CrystalBall/Area2D
#@onready var container: HBoxContainer = $InsideCrystalBall/CardDisplay/HBoxContainer
#@onready var preview_sprite: Sprite2D = $InsideCrystalBall/PreviewSprite
@onready var preview_sprite: Sprite2D = $InsideCrystalBall/Preview/MaskLayer/PreviewSprite
@onready var mask_layer: NinePatchRect = $InsideCrystalBall/Preview/MaskLayer
@onready var card_frame: NinePatchRect = $InsideCrystalBall/Preview/CardFrame
@onready var preview: Sprite2D = $InsideCrystalBall/Preview
@onready var top_container: HBoxContainer = $InsideCrystalBall/CardDisplay/TopContainer
@onready var bottom_container: HBoxContainer = $InsideCrystalBall/CardDisplay/BottomContainer
@onready var checkmark: Node2D = $InsideCrystalBall/Checkmark
@onready var checkmark_area: Node = $InsideCrystalBall/Checkmark/ClickableArea


var suspect_paths: Array[String] = []
var weapon_paths: Array[String] = []
var location_paths: Array[String] = []

var current_texture_path: String
var submissions: Dictionary = {}
var skip_token_state: Array[int] = []

var crystal_ball_tween: Tween

const NUM_TOKENS = 3


func _ready() -> void:
	left_clickable_area.mouse_clicked.connect(_on_left_arrow_clicked)
	right_clickable_area.mouse_clicked.connect(_on_right_arrow_clicked)
	clickable_area.mouse_clicked.connect(_on_crystal_ball_clicked)
	checkmark_area.mouse_clicked.connect(_on_checkmark_clicked)
	
	tokens.frame = TokenType.WEAPON


func reset_submissions_same_track(solved_categories: Array):
	tokens.frame = TokenType.WEAPON
	
	submissions = {}
	skip_token_state.clear()
	if solved_categories.has("weapon"):
		skip_token_state.append(TokenType.WEAPON)
	if solved_categories.has("suspect"):
		skip_token_state.append(TokenType.SUSPECT)
	if solved_categories.has("location"):
		skip_token_state.append(TokenType.LOCATION)
	
	while(true):
		tokens.frame = (tokens.frame + 1) % NUM_TOKENS
		
		if !(tokens.frame in skip_token_state) or skip_token_state.size() == 3:
			break
	
	_refresh_selection_ui()


func reset_submissions_new_track():
	tokens.frame = TokenType.WEAPON
	submissions = {}
	skip_token_state.clear()
	_refresh_selection_ui()


func _on_checkmark_clicked():
	checkmark.visible = false
	rpc("send_guess_submission", tokens.frame, current_texture_path)


@rpc("any_peer", "call_local", "reliable")
func send_guess_submission(token_frame: int, texture_path: String):
	checkmark.visible = false
	
	submissions[token_frame + 1] = texture_path
	
	skip_token_state.append(token_frame)
	
	if skip_token_state.size() < 3:
		if tokens.frame == token_frame:
			_on_right_arrow_clicked()
	elif multiplayer.is_server():
		GameManager.evaluate_crystal_ball_submissions()
		GameManager.change_game_phase.rpc("end_round")


func _on_left_arrow_clicked():
	while(true):
		if tokens.frame == 0:
			tokens.frame = NUM_TOKENS - 1
		else:
			tokens.frame -= 1
			
		if !(tokens.frame in skip_token_state) and skip_token_state.size() < 3:
			break
	_bounce_token()
	_refresh_selection_ui()


func _on_right_arrow_clicked():
	while(true):
		tokens.frame = (tokens.frame + 1) % NUM_TOKENS
		
		if !(tokens.frame in skip_token_state) and skip_token_state.size() < 3:
			break
	_bounce_token()
	_refresh_selection_ui()


func _bounce_token():
	token_audio_stream_player.pitch_scale = randf_range(1.9, 2.0)
	token_audio_stream_player.play()
	
	var tween = create_tween()

	tween.tween_property(tokens, "scale", Vector2(1.2, 1.2), 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	tween.tween_property(tokens, "scale", Vector2(1.0, 1.0), 0.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _on_crystal_ball_clicked():
	chime_audio_stream_player.play()
	
	_refresh_selection_ui()
	
	if crystal_ball_tween and crystal_ball_tween.is_running():
		crystal_ball_tween.kill()
		
	crystal_ball_tween = create_tween()
	if get_parent().has_node("PlayerUI"):
		get_parent().player_ui.visible = false
	
	area_2d.visible = false

	crystal_ball_tween.set_parallel(true)
	crystal_ball_tween.set_trans(Tween.TRANS_CUBIC)
	crystal_ball_tween.set_ease(Tween.EASE_OUT)

	crystal_ball_tween.tween_property(crystal_ball_above, "modulate:a", 1.0, 1).from(0.0)
	crystal_ball_tween.tween_property(crystal_ball_above, "position:y", 40, 0.8).from(0.0)
	crystal_ball_tween.tween_property(crystal_ball_above, "scale", Vector2(1.5, 1.5), 3).from(Vector2(0.9, 0.9))

	var delay = 0.7
	crystal_ball_tween.tween_property(inside_crystal_ball, "modulate:a", 1.0, 2).from(0.0).set_delay(delay)
	crystal_ball_tween.tween_property(inside_crystal_ball, "scale", Vector2(1.0, 1.0), 0.8).from(Vector2(0.9, 0.9)).set_delay(delay)


func reset_visuals():
	if crystal_ball_tween and crystal_ball_tween.is_running():
		crystal_ball_tween.kill()
		
	crystal_ball_above.modulate.a = 0
	inside_crystal_ball.modulate.a = 0
	area_2d.visible = true


#func reset_state():
	#skip_token_state.clear()


func setup_crystal_ball(s_paths: Array, w_paths: Array, l_paths: Array):
	# convert incoming generic arrays to typed string arrays
	suspect_paths = Array(s_paths, TYPE_STRING, &"", null)
	weapon_paths = Array(w_paths, TYPE_STRING, &"", null)
	location_paths = Array(l_paths, TYPE_STRING, &"", null)
	
	print("CRYSTAL BALL WAS SETUP")


func _refresh_selection_ui():
	checkmark.visible = false
	
	if tokens.frame < TokenType.LOCATION:
		inside_crystal_ball_bg.rotation_degrees = 0
		inside_crystal_ball_bg.texture = preload("uid://bb68irlyms4m4")

	var paths_to_load: Array[String] = []
	
	preview.visible = false
	
	preview_sprite.texture = null
	
	match tokens.frame:
		TokenType.WEAPON:
			paths_to_load = weapon_paths
		TokenType.SUSPECT:
			paths_to_load = suspect_paths
		TokenType.LOCATION:
			paths_to_load = location_paths
	populate_selection_menu(paths_to_load)


func populate_selection_menu(texture_paths: Array):
	# clear existing buttons
	for child in top_container.get_children():
		child.queue_free()
	for child in bottom_container.get_children():
		child.queue_free()
		
	var top_container_size = int(texture_paths.size() / 2)
	
	var count = 0
	
	# loop through the paths sent from the server/ghost
	for path in texture_paths:
		count += 1
		
		if path == "": continue
		
		var button = Button.new()
		
		# convert path "res://assets/.../the_chef.png" -> "The Chef"
		button.text = _get_clean_name(path)
		
		# connect the button to the preview logic
		if tokens.frame != TokenType.LOCATION:
			button.pressed.connect(_on_item_button_pressed.bind(path))
		else:
			button.pressed.connect(_on_location_button_pressed.bind(path))
		
		button.pressed.connect(func(): button_audio_stream_player.play())
		
		if count <= top_container_size:
			top_container.add_child(button)
		else:
			bottom_container.add_child(button)


func _get_clean_name(path: String) -> String:
	# "the_chef.png" -> "the_chef"
	var base_name = path.get_file().get_basename()
	# "the_chef" -> "The Chef"
	return base_name.replace("_", " ").capitalize()


func _on_item_button_pressed(path: String):
	var texture = load(path)
	current_texture_path = path
	checkmark.visible = true
	
	if texture is Texture2D:
		preview_sprite.texture = texture
		match tokens.frame:
			TokenType.WEAPON: card_frame.texture = preload("uid://240yaag32lqm")
			TokenType.SUSPECT: card_frame.texture = preload("uid://cnfs0t5f87raw")
			TokenType.LOCATION: card_frame.texture = preload("uid://wyg3wb5uxx4b")
		var art_size = preview_sprite.texture.get_size()
		mask_layer.size = art_size
		mask_layer.position = -art_size / 2
		card_frame.size = art_size
		card_frame.position = -art_size / 2
		preview_sprite.offset = art_size / 2
		
		preview.rotation_degrees = 90
		preview.visible = true
		
		# animation
		var tween = create_tween()
		tween.tween_property(preview, "scale", Vector2(1.1, 1.1), 0.05)
		tween.tween_property(preview, "scale", Vector2(1.0, 1.0), 0.1)


func _on_location_button_pressed(path: String):
	var texture = load(path)
	current_texture_path = path
	checkmark.visible = true
	
	if texture is Texture2D:
		inside_crystal_ball_bg.rotation_degrees = 90
		inside_crystal_ball_bg.texture = texture
		
		preview_sprite.texture = null
		preview.visible = false
		
		# animation
		var tween = create_tween()
		tween.tween_property(inside_crystal_ball_bg, "scale", Vector2(1.025, 1.025), 0.05)
		tween.tween_property(inside_crystal_ball_bg, "scale", Vector2(1.0, 1.0), 0.1)
