extends Node

var peer = ENetMultiplayerPeer.new()
var players = {} # peer_id -> name
var my_name = "Player"

signal player_connected(peer_id, player_info)
signal player_disconnected(peer_id)
signal server_disconnected

func _ready():
	multiplayer.peer_connected.connect(_on_player_connected)
	multiplayer.peer_disconnected.connect(_on_player_disconnected)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

func join_game(address, port):
	var error = peer.create_client(address, port)
	if error:
		return error
	multiplayer.multiplayer_peer = peer
	return OK

func host_game(port):
	var error = peer.create_server(port, 4)
	if error:
		return error
	multiplayer.multiplayer_peer = peer
	players[1] = my_name
	player_connected.emit(1, my_name)
	return OK

func _on_player_connected(id):
	rpc_id(id, "register_player", my_name)

@rpc("any_peer", "reliable")
func register_player(new_player_name):
	var id = multiplayer.get_remote_sender_id()
	players[id] = new_player_name
	player_connected.emit(id, new_player_name)

func _on_player_disconnected(id):
	players.erase(id)
	player_disconnected.emit(id)

func _on_server_disconnected():
	multiplayer.multiplayer_peer = null
	players.clear()
	server_disconnected.emit()

@rpc("any_peer", "call_local", "reliable")
func start_game_rpc():
	get_tree().change_scene_to_file("res://game.tscn")
