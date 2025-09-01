extends Node

const PORT = 9999
var peer

signal player_connected(id)
signal player_disconnected(id)
signal connected_to_server
signal connection_failed
signal server_disconnected

func _ready():
	print("NetworkManager is ready")
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

func create_server():
	peer = ENetMultiplayerPeer.new()
	var error = peer.create_server(PORT)
	if error != OK:
		print("cannot create server")
		return
	multiplayer.set_multiplayer_peer(peer)
	print("Server created")

func join_server(ip_address):
	peer = ENetMultiplayerPeer.new()
	peer.create_client(ip_address, PORT)
	multiplayer.set_multiplayer_peer(peer)

func _on_peer_connected(id):
	print("Player connected: " + str(id))
	emit_signal("player_connected", id)

func _on_peer_disconnected(id):
	print("Player disconnected: " + str(id))
	emit_signal("player_disconnected", id)

func _on_connected_to_server():
	print("Connected to server")
	emit_signal("connected_to_server")

func _on_connection_failed():
	print("Connection failed")
	emit_signal("connection_failed")

func _on_server_disconnected():
	print("Server disconnected")
	emit_signal("server_disconnected")
