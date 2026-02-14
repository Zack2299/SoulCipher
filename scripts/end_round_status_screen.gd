extends Node2D

@onready var weapon_token: Sprite2D = $WeaponToken
@onready var suspect_token: Sprite2D = $SuspectToken
@onready var location_token: Sprite2D = $LocationToken
@onready var woosh_audio_stream_player: AudioStreamPlayer = $WooshAudioStreamPlayer

@onready var token_map = {
	"weapon": weapon_token,
	"suspect": suspect_token,
	"location": location_token
}


func _ready():
	reset_tokens()
	
func reset_tokens():
	for token in token_map.values():
		token.modulate.a = 0
		token.scale = Vector2(5, 5)


func display_results(solved_categories: Array):
	var delay = 0.0
	
	await get_tree().create_timer(2).timeout
	
	for category in token_map.keys():
		if solved_categories.has(category):
			var token = token_map[category]
			# only animate if not alreadyt solved previously
			if token.modulate.a < 1.0:
				animate_token_in(token, delay)
				delay += 0.4 # stagger animations
	

func animate_token_in(token: Sprite2D, delay: float):	
	var tween = create_tween().set_parallel(true)
	
	token.z_index = 10
	
	# fade
	tween.tween_property(token, "modulate:a", 1.0, 0.5)\
		.set_trans(Tween.TRANS_CUBIC)\
		.set_delay(delay)
	
	# drop in (scale)
	tween.tween_property(token, "scale", Vector2(1, 1), 2)\
		.set_trans(Tween.TRANS_CUBIC)\
		.set_ease(Tween.EASE_OUT)\
		.set_delay(delay)
	
	# rotate
	token.rotation = deg_to_rad(-90)
	tween.tween_property(token, "rotation", 0.0, 2)\
		.set_trans(Tween.TRANS_CUBIC)\
		.set_ease(Tween.EASE_OUT)\
		.set_delay(delay)
		
	tween.finished.connect(func(): token.z_index = 1)
	
	await get_tree().create_timer(delay).timeout
	
	woosh_audio_stream_player.play()
