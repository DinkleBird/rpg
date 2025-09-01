extends Node2D

var player_scene = preload("res://player.tscn")

func _ready():
	NetworkManager.player_connected.connect(_on_player_connected)
	NetworkManager.server_disconnected.connect(_on_server_disconnected)

	if multiplayer.is_server():
		_on_player_connected(multiplayer.get_unique_id())

func _on_player_connected(id):
	var player = player_scene.instantiate()
	player.name = str(id)
	add_child(player)

func _on_server_disconnected():
	get_tree().reload_current_scene()
