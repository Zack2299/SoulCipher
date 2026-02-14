extends Node2D
@onready var end_round_status_screen: Node2D = $EndRoundStatusScreen

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	#end_round_status_screen.display_results(["weapon", "location"])
	#end_round_status_screen.display_results(["location"])
	
	#await get_tree().create_timer(5).timeout
	
	end_round_status_screen.display_results(["weapon", "suspect", "location"])
