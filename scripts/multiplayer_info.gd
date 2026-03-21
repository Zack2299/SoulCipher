class_name MultiplayerInfo
extends Resource

const SAVE_PATH := "user://saved_info.tres"

@export var last_used_ip: String = "127.0.0.1"
@export var last_used_port: String = "8080"
@export var last_used_name: String = "Player"

func write_info() -> void:
	ResourceSaver.save(self, SAVE_PATH)


static func load_info() -> Resource:
	if ResourceLoader.exists(SAVE_PATH):
		return load(SAVE_PATH)
	return null
